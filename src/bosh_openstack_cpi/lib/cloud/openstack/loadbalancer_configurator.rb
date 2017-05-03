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

        lb_member = @openstack.with_openstack {
          @openstack.network.create_lbaas_pool_member(openstack_pool_id, ip, pool_spec['port'], { subnet_id: subnet_id })
        }
        LoadbalancerPoolMembership.new(pool_spec['name'], pool_spec['port'], openstack_pool_id, lb_member.body['member']['id'])
      rescue Bosh::Clouds::VMCreationFailed => e
        message = "VM with id '#{server.id}' cannot be attached to load balancer pool '#{pool_spec['name']}'. Reason: #{e.message}"
        raise Bosh::Clouds::VMCreationFailed.new(false), message
      end
    end

    def cleanup_memberships(server_metadata)
      server_metadata
        .select { |key, _| key.start_with?('lbaas_pool_') }
        .map { |_, value| value.split('/') }
        .each { |pool_id, membership_id| remove_vm_from_pool(pool_id, membership_id) }
    end


    def remove_vm_from_pool(pool_id, membership_id)
      begin
        @openstack.with_openstack{ @openstack.network.delete_lbaas_pool_member(pool_id, membership_id) }
      rescue Fog::Network::OpenStack::NotFound
        @logger.debug("Skipping deletion of lbaas pool member. Member with pool_id '#{pool_id}' and membership_id '#{membership_id}' does not exist.")
      rescue => e
        raise Bosh::Clouds::CloudError, "Deleting LBaaS member with pool_id '#{pool_id}' and membership_id '#{membership_id}' failed. Reason: #{e.class.to_s} #{e.message}"
      end
    end

    private

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
  end
end

