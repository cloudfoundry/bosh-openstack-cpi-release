module Bosh::OpenStackCloud
  class Server
    include Helpers

    REGISTRY_KEY_TAG = :registry_key

    def initialize(agent_properties, human_readable_vm_names, logger, openstack, registry, use_dhcp)
      @agent_properties = agent_properties
      @human_readable_vm_names = human_readable_vm_names
      @logger = logger
      @openstack = openstack
      @registry = registry
      @use_dhcp = use_dhcp
    end

    attr_reader :use_dhcp

    def create(agent_settings, network_configurator, resource_pool, create_vm_params)
      create_vm_params = create_vm_params.dup

      begin
        nics = network_configurator.nics
        @logger.debug("Using NICs: `#{nics.join(', ')}'")
        create_vm_params[:nics] = nics
        create_vm_params[:user_data] = JSON.dump(
          user_data(create_vm_params[:name], network_configurator.network_spec, agent_settings),
        )

        server = create_server(create_vm_params)
        configure_server(network_configurator, server)

        server_tags = {}
        tag_server(server_tags, server, agent_settings.registry_key, network_configurator.network_spec, resource_pool.fetch('loadbalancer_pools', []))
        update_server_settings(server, agent_settings)

        server.id.to_s
      rescue StandardError => e
        begin
          destroy(server, server_tags) if server
        rescue StandardError => destroy_err
          @logger.warn("Failed to destroy server: #{destroy_err.message}")
        end

        raise e
      end
    end

    def destroy(server, server_tags)
      server_tags ||= {}
      server_port_ids = NetworkConfigurator.port_ids(@openstack, server.id)
      @logger.debug("Network ports: `#{server_port_ids.join(', ')}' found for server #{server.id}")

      lbaas_error = catch_error('Removing lbaas pool memberships') { LoadbalancerConfigurator.new(@openstack, @logger).cleanup_memberships(server_tags) }
      @openstack.with_openstack(retryable: true, ignore_not_found: true) { server.destroy }
      fail_on_error(
        catch_error('Wait for server deletion') { @openstack.wait_resource(server, %i[terminated deleted], :state, true) },
        catch_error('Removing ports') { NetworkConfigurator.cleanup_ports(@openstack, server_port_ids) },
        lbaas_error,
        catch_error('Deleting registry settings') {
          registry_key = server_tags.fetch(REGISTRY_KEY_TAG.to_s, server.name)
          unless @registry.instance_of? NoopRegistry
           @logger.info("Deleting settings for server `#{server.id}' with registry_key `#{registry_key}' ...")
          end
          @registry.delete_settings(registry_key)
        },
      )
    end

    private

    def create_server(create_vm_params)
      @logger.debug("Using boot params: `#{Bosh::Cpi::Redactor.clone_and_redact(create_vm_params, 'user_data').inspect}'")
      server = @openstack.with_openstack do
        begin
          @openstack.compute.servers.create(create_vm_params)
        rescue Excon::Error::Timeout => e
          @logger.debug(e.backtrace)
          cloud_error_message = "VM creation with name '#{create_vm_params[:name]}' received a timeout. " \
                                "The VM might still have been created by OpenStack.\nOriginal message: "
          raise Bosh::Clouds::VMCreationFailed.new(false), cloud_error_message + e.message
        rescue Excon::Error::BadRequest, Excon::Error::NotFound, Fog::OpenStack::Compute::NotFound => e
          raise e if @openstack.use_nova_networking?
          not_existing_net_ids = not_existing_net_ids(create_vm_params[:nics])
          raise e if not_existing_net_ids.empty?
          @logger.debug(e.backtrace)
          cloud_error_message = "VM creation with name '#{create_vm_params[:name]}' failed. Following network " \
                                "IDs are not existing or not accessible from this project: '#{not_existing_net_ids.join(',')}'. " \
                                'Make sure you do not use subnet IDs'
          raise Bosh::Clouds::VMCreationFailed.new(false), cloud_error_message
        end
      end
      server
    end

    def configure_server(network_configurator, server)
      @logger.info("Creating new server `#{server.id}'...")
      begin
        @openstack.wait_resource(server, :active, :state)

        @logger.info("Configuring network for server `#{server.id}'...")
        network_configurator.configure(@openstack, server)
      rescue StandardError => e
        @logger.warn("Failed to create server: #{e.message}")
        raise Bosh::Clouds::VMCreationFailed.new(true), e.message
      end
    end

    def tag_server(server_tags, server, registry_key, network_spec, loadbalancer_pools)
      if @human_readable_vm_names
        @logger.debug("'human_readable_vm_names' enabled")

        server_tags[REGISTRY_KEY_TAG] = registry_key
      else
        @logger.debug("'human_readable_vm_names' disabled")
      end

      server_tags.merge!(
        LoadbalancerConfigurator
        .new(@openstack, @logger)
        .create_pool_memberships(server, network_spec, loadbalancer_pools),
      )

      begin
        unless server_tags.empty?
          TagManager.tag_server(server, server_tags)
          @logger.debug("Tagged VM '#{server.id}' with tags '#{server_tags}")
        end
      rescue StandardError => e
        @logger.warn("Unable to tag server with tags '#{server_tags}")
        raise Bosh::Clouds::VMCreationFailed.new(true), e.message
      end
    end

    def update_server_settings(server, agent_settings)
      settings = initial_agent_settings(agent_settings)
      @logger.info("Updating settings for server `#{server.id}'...") unless @registry.instance_of? NoopRegistry
      @registry.update_settings(agent_settings.registry_key, settings)
    rescue StandardError => e
      @logger.warn("Failed to register server: #{e.message}")
      raise Bosh::Clouds::VMCreationFailed.new(false), e.message
    end

    ##
    # Prepare server user data
    #
    # @param [String] registry_key used by agent to look up settings from registry
    # @param [Hash] network_spec network specification
    # @return [Hash] server user data
    def user_data(registry_key, network_spec, agent_settings, public_key = nil)
      data = {}

      data['server'] = { 'name' => registry_key }
      data['openssh'] = { 'public_key' => public_key } if public_key
      data['networks'] = agent_network_spec(network_spec)

      with_dns(network_spec) do |servers|
        data['dns'] = { 'nameserver' => servers }
      end

      if @registry.endpoint
        data['registry'] = { 'endpoint' => @registry.endpoint }
      else
        data.merge!(initial_agent_settings(agent_settings))
      end

      data
    end

    def not_existing_net_ids(nics)
      result = []
      begin
        network = @openstack.network
        nics.each do |nic|
          if nic['net_id']
            result << nic['net_id'] unless @openstack.with_openstack(retryable: true) { network.networks.get(nic['net_id']) }
          end
        end
      rescue StandardError => e
        @logger.warn(e.backtrace)
      end
      result
    end

    ##
    # Generates initial agent settings. These settings will be used by Bosh Agent
    # server. Disk conventions in Bosh Agent for OpenStack are:
    # - system disk: /dev/sda
    # - ephemeral disk: /dev/sdb
    # - persistent disks: /dev/sdc through /dev/sdz
    # As some kernels remap device names (from sd* to vd* or xvd*), Bosh Agent will lookup for the proper device name
    def initial_agent_settings(agent_settings)
      settings = {
        'vm' => {
          'name' => agent_settings.registry_key,
        },
        'agent_id' => agent_settings.agent_id,
        'networks' => agent_network_spec(agent_settings.network_spec),
        'disks' => {
          'system' => '/dev/sda',
          'persistent' => {},
        },
      }

      settings['disks']['ephemeral'] = agent_settings.has_ephemeral ? '/dev/sdb' : nil
      settings['env'] = agent_settings.environment if agent_settings.environment
      settings.merge(@agent_properties)
    end

    def agent_network_spec(network_spec)
      network_spec.map do |name, settings|
        settings['use_dhcp'] = @use_dhcp unless settings['type'] == 'vip'
        [name, settings]
      end.to_h
    end

    ##
    # Extract dns server list from network spec and yield the the list
    #
    # @param [Hash] network_spec network specification for instance
    # @yield [Array]
    def with_dns(network_spec)
      network_spec.each_value do |properties|
        if properties.key?('dns') && !properties['dns'].nil?
          yield properties['dns']
        end
      end
    end

  end
end
