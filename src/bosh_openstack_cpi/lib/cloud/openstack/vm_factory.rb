module Bosh::OpenStackCloud
  class VmFactory
    include Helpers

    def initialize(openstack, server, create_vm_params, disk_locality, az_provider, openstack_properties)
      @openstack = openstack
      @server = server

      @create_vm_params = create_vm_params
      @disk_locality = disk_locality
      @az_provider = az_provider
      @openstack_properties = openstack_properties

      @logger = Bosh::Clouds::Config.logger
    end

    def create_vm(network_configurator, agent_id, environment, stemcell_id, cloud_properties)
      pick_security_groups(@create_vm_params, ResourcePool.security_groups(cloud_properties), network_configurator)
      pick_stemcell(@create_vm_params, stemcell_id)
      flavor = pick_flavor(@create_vm_params, cloud_properties)
      pick_key_name(@create_vm_params, cloud_properties)
      pick_server_groups(@create_vm_params, environment)
      configure_volumes(@create_vm_params, flavor, cloud_properties)

      agent_settings = OpenStruct.new(
        registry_key: @create_vm_params[:name],
        agent_id: agent_id,
        environment: environment,
        has_ephemeral: flavor_has_ephemeral_disk?(flavor),
        network_spec: network_configurator.network_spec,
      )

      VmCreator.new(network_configurator, @server, @az_provider, cloud_properties, agent_settings, @create_vm_params).perform
    end

    private

    def pick_security_groups(server_params, resource_pool_groups, network_configurator)
      network_configurator.check_preconditions(@openstack.use_nova_networking?, @create_vm_params[:config_drive], @server.use_dhcp)
      network_configurator.pick_groups(@openstack, @openstack_properties.default_security_groups, resource_pool_groups)
      server_params[:security_groups] = network_configurator.picked_security_groups.map(&:name)
    end

    def pick_stemcell(server_params, stemcell_id)
      stemcell = Stemcell.create(@logger, @openstack, stemcell_id)
      stemcell.validate_existence
      server_params[:image_ref] = stemcell.image_id
    end

    def pick_flavor(server_params, resource_pool)
      compute = @openstack.with_openstack { @openstack.compute }
      flavor = @openstack.with_openstack(retryable: true) do
        compute.flavors.find { |f| f.name == resource_pool['instance_type'] }
      end
      cloud_error("Flavor `#{resource_pool['instance_type']}' not found") if flavor.nil?
      if flavor_has_ephemeral_disk?(flavor)
        if flavor.ram
          # Ephemeral disk size should be at least the double of the vm total memory size, as agent will need:
          # - vm total memory size for swapon,
          # - the rest for /var/vcap/data
          min_ephemeral_size = (flavor.ram / 1024) * 2
          if flavor.ephemeral < min_ephemeral_size
            cloud_error("Flavor `#{resource_pool['instance_type']}' should have at least #{min_ephemeral_size}Gb " \
                        'of ephemeral disk')
          end
        end
      end
      @logger.debug("Using flavor: `#{resource_pool['instance_type']}'")
      server_params[:flavor_ref] = flavor.id
      flavor
    end

    def pick_key_name(server_params, resource_pool)
      keyname = resource_pool['key_name'] || @openstack_properties.default_key_name
      validate_key_exists(keyname)
      server_params[:key_name] = keyname
    end

    def validate_key_exists(keyname)
      keypair = @openstack.with_openstack(retryable: true) { @openstack.compute.key_pairs.find { |k| k.name == keyname } }
      cloud_error("Key-pair `#{keyname}' not found") if keypair.nil?
      @logger.debug("Using key-pair: `#{keypair.name}' (#{keypair.fingerprint})")
    end

    def pick_server_groups(server_params, environment)
      return unless @openstack_properties.enable_auto_anti_affinity
      bosh_group = environment.dig('bosh', 'group')
      return unless bosh_group

      if server_params.dig(:os_scheduler_hints, 'group')
        @logger.debug("Won't create/use server group for bosh group '#{bosh_group}'. Using provided server group with id '#{server_params[:os_scheduler_hints]['group']}'.")
        return
      end

      server_group_id = ServerGroups.new(@openstack).find_or_create(Bosh::Clouds::Config.uuid, bosh_group)
      server_group_hint = { 'group' => server_group_id }
      return server_params[:os_scheduler_hints].merge!(server_group_hint) if server_params[:os_scheduler_hints]
      server_params[:os_scheduler_hints] = server_group_hint
    end

    def configure_volumes(server_params, flavor, resource_pool)
      volume_configurator = Bosh::OpenStackCloud::VolumeConfigurator.new(@logger)
      return unless volume_configurator.boot_from_volume?(@openstack_properties.boot_from_volume, resource_pool)

      boot_vol_size = volume_configurator.select_boot_volume_size(flavor, resource_pool)
      server_params[:block_device_mapping_v2] = [{
        uuid: server_params[:image_ref],
        source_type: 'image',
        destination_type: 'volume',
        volume_size: boot_vol_size,
        boot_index: '0',
        delete_on_termination: '1',
        device_name: '/dev/vda',
      }]
      server_params.delete(:image_ref)
    end

    ##
    # Checks if the OpenStack flavor has ephemeral disk
    #
    # @param [Fog::OpenStack::Compute::Flavor] OpenStack flavor
    # @return [Boolean] true if flavor has ephemeral disk, false otherwise
    def flavor_has_ephemeral_disk?(flavor)
      flavor.ephemeral && flavor.ephemeral.to_i > 0
    end

  end
end
