module Bosh::OpenStackCloud
  class LoadbalancerConfigurator

    def initialize(openstack, logger)
      @openstack = openstack
      @logger = logger
    end

    def create_pool_memberships(server, network_spec, pools)
      pools
        .map { |pool| add_vm_to_pool(server, network_spec, pool)}
        .each_with_index
        .map do |membership, index|
          ["lbaas_pool_#{index+1}", "#{membership.pool_id}/#{membership.membership_id}"]
        end
        .to_h
    end

    def add_vm_to_pool(server, network_spec, pool_spec)
      begin
        validate_configuration(pool_spec)
        openstack_pool_id = openstack_pool_id(pool_spec['name'])
        ip = NetworkConfigurator.gateway_ip(network_spec, @openstack, server)
        subnet_id = matching_subnet_id(network_spec, ip)
        membership_id = create_membership(openstack_pool_id, ip, pool_spec['port'], subnet_id)
        LoadbalancerPoolMembership.new(pool_spec['name'], pool_spec['port'], openstack_pool_id, membership_id)
      rescue Bosh::Clouds::VMCreationFailed => e
        message = "VM with id '#{server.id}' cannot be attached to load balancer pool '#{pool_spec['name']}'. Reason: #{e.message}"
        raise Bosh::Clouds::VMCreationFailed.new(false), message
      end
    end

    def create_membership(pool_id, ip, port, subnet_id)
      @openstack.with_openstack do
        begin
          loadbalancer_id = loadbalancer_id(pool_id)
          resource = LoadBalancerResource.new(loadbalancer_id, @openstack)
          @openstack.wait_resource(resource, :active, :provisioning_status)
          pool_member_response = @openstack.network.create_lbaas_pool_member(pool_id, ip, port, {subnet_id: subnet_id})
          @openstack.wait_resource(resource, :active, :provisioning_status)
          pool_member_response.body['member']['id']
        rescue LoadBalancerResource::NotFound, LoadBalancerResource::NotSupportedConfiguration => e
          raise Bosh::Clouds::VMCreationFailed.new(false), e.message
        rescue Excon::Error::Conflict
          membership_id = @openstack
            .network
            .list_lbaas_pool_members(pool_id)
            .body
            .fetch('members', [])
            .detect(
              raise_if_not_found(pool_id, ip, port),
              &matching_member(ip, port, subnet_id)
            )
            .fetch('id')

          @logger.info("Load balancer pool membership with pool id '#{pool_id}', ip '#{ip}', and port '#{port}' already exists. The membership has the id '#{membership_id}'.")

          membership_id
        end
      end
    end

    def raise_if_not_found(pool_id, ip, port)
      lambda { raise Bosh::Clouds::CloudError, "Load balancer pool membership with pool id '#{pool_id}', ip '#{ip}', and port '#{port}' supposedly exists, but cannot be found." }
    end

    def matching_member(ip, port, subnet_id)
      lambda { |member| member['address'] == ip && member['protocol_port'] == port && member['subnet_id'] == subnet_id }
    end

    def cleanup_memberships(server_metadata)
      server_metadata
        .select { |key, _| key.start_with?('lbaas_pool_') }
        .map { |_, value| value.split('/') }
        .each { |pool_id, membership_id| remove_vm_from_pool(pool_id, membership_id) }
    end

    def remove_vm_from_pool(pool_id, membership_id)
      begin
        loadbalancer_id = loadbalancer_id(pool_id)
        resource = LoadBalancerResource.new(loadbalancer_id, @openstack)
        @openstack.wait_resource(resource, :active, :provisioning_status)
        @openstack.with_openstack do
          begin
            @openstack.network.delete_lbaas_pool_member(pool_id, membership_id)
          rescue Fog::Network::OpenStack::NotFound
            @logger.debug("Skipping deletion of lbaas pool member. Member with pool_id '#{pool_id}' and membership_id '#{membership_id}' does not exist.")
          end
        end
        @openstack.wait_resource(resource, :active, :provisioning_status)
      rescue LoadBalancerResource::NotFound => e
        @logger.debug("Skipping deletion of lbaas pool member because load balancer resource cannot be found. #{e.message}")
      rescue => e
        raise Bosh::Clouds::CloudError, "Deleting LBaaS member with pool_id '#{pool_id}' and membership_id '#{membership_id}' failed. Reason: #{e.class.to_s} #{e.message}"
      end
    end

    def loadbalancer_id(pool_id)
      @openstack.with_openstack do
        begin
          pool_response = @openstack.network.get_lbaas_pool(pool_id)
          loadbalancers = pool_response.body['pool']['loadbalancers'] ||
              retrieve_loadbalancers_via_listener(
                  pool_response.body['pool']['listeners'],
                  pool_id
              )
          extract_loadbalancer_id(loadbalancers, pool_id)
        rescue Fog::Network::OpenStack::NotFound => e
          raise LoadBalancerResource::NotFound, "Load balancer ID could not be determined because pool with ID '#{pool_id}' was not found. Reason: #{e.message}"
        end
      end
    end

    private

    def retrieve_loadbalancers_via_listener(listeners, pool_id)
      if listeners.empty?
        raise LoadBalancerResource::NotFound, "No listeners associated with LBaaS pool '#{pool_id}'"
      elsif listeners.size > 1
        raise LoadBalancerResource::NotSupportedConfiguration, "More than one listener is associated with LBaaS pool '#{pool_id}'. It is not possible to verify the status of the loadbalancer responsible for the pool membership."
      end

      listener_response = @openstack.with_openstack{ @openstack.network.get_lbaas_listener(listeners[0]['id']) }
      listener_response.body['listener']['loadbalancers']
    end

    def extract_loadbalancer_id(loadbalancers, pool_id)
      if loadbalancers.empty?
        raise LoadBalancerResource::NotFound, "No loadbalancers associated with LBaaS pool '#{pool_id}'"
      elsif loadbalancers.size > 1
        raise LoadBalancerResource::NotSupportedConfiguration, "More than one loadbalancer is associated with LBaaS pool '#{pool_id}'. It is not possible to verify the status of the loadbalancer responsible for the pool membership."
      end

      loadbalancers[0]['id']
    end

    def matching_subnet_id(network_spec, ip)
      subnet_ids = NetworkConfigurator.matching_gateway_subnet_ids_for_ip(network_spec, @openstack, ip)
      if subnet_ids.size > 1
        raise Bosh::Clouds::VMCreationFailed.new(false), "In network '#{NetworkConfigurator.get_gateway_network_id(network_spec)}' more than one subnet CIDRs match the IP '#{ip}'"
      end
      if subnet_ids.empty?
        raise Bosh::Clouds::VMCreationFailed.new(false), "Network '#{NetworkConfigurator.get_gateway_network_id(network_spec)}' does not contain any subnet to match the IP '#{ip}'"
      end
      subnet_ids.first
    end

    def validate_configuration(pool_spec)
      unless pool_spec['name']
        raise Bosh::Clouds::VMCreationFailed.new(false), 'Load balancer pool defined without a name'
      end

      unless pool_spec['port']
        raise Bosh::Clouds::VMCreationFailed.new(false), "Load balancer pool '#{pool_spec['name']}' has no port definition"
      end
    end

    class LoadbalancerPoolMembership
      attr_reader :name, :port, :membership_id, :pool_id

      def initialize(name, port, pool_id, membership_id)
        @name = name
        @port = port
        @pool_id = pool_id
        @membership_id = membership_id
      end
    end

    def openstack_pool_id(pool_name)
      pools = @openstack.with_openstack {
        @openstack.network.list_lbaas_pools({ 'name' => pool_name }).body['pools']
      }

      if pools.empty?
        raise Bosh::Clouds::VMCreationFailed.new(false), "Load balancer pool '#{pool_name}' does not exist"
      elsif pools.size > 1
        raise Bosh::Clouds::VMCreationFailed.new(false), "Load balancer pool '#{pool_name}' exists multiple times. Make sure to use unique naming."
      end
      pools.first['id']
    end

    class LoadBalancerResource
      attr_reader :id

      def initialize(loadbalancer_id, openstack)
        @id = loadbalancer_id
        @openstack = openstack
      end

      def reload
        true
      end

      def provisioning_status
        @openstack.network.get_lbaas_loadbalancer(@id).body['loadbalancer']['provisioning_status']
      end

      class NotFound < StandardError; end
      class NotSupportedConfiguration < StandardError; end
    end
  end
end

