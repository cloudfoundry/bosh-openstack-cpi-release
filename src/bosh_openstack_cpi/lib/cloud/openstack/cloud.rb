module Bosh::OpenStackCloud
  ##
  # BOSH OpenStack CPI
  class Cloud < Bosh::Cloud
    include Helpers

    OPTION_KEYS = %w[openstack registry agent use_dhcp].freeze

    BOSH_APP_DIR = '/var/vcap/bosh'.freeze
    FIRST_DEVICE_NAME_LETTER = 'b'.freeze
    REGISTRY_KEY_TAG = :registry_key

    attr_reader :registry
    attr_reader :state_timeout
    attr_reader :openstack
    attr_accessor :logger

    ##
    # Creates a new BOSH OpenStack CPI
    #
    # @param [Hash] options CPI options
    # @option options [Hash] openstack OpenStack specific options
    # @option options [Hash] agent agent options
    # @option options [Hash] registry agent options
    def initialize(options)
      @options = normalize_options(options)

      validate_options
      initialize_registry

      @logger = Bosh::Clouds::Config.logger

      @agent_properties = @options.fetch('agent', {})
      openstack_properties = @options['openstack']
      @default_key_name = openstack_properties['default_key_name']
      @default_security_groups = openstack_properties['default_security_groups']
      @default_volume_type = openstack_properties['default_volume_type']
      @stemcell_public_visibility = openstack_properties['stemcell_public_visibility']
      @boot_from_volume = openstack_properties['boot_from_volume']
      @use_dhcp = openstack_properties['use_dhcp']
      @human_readable_vm_names = openstack_properties['human_readable_vm_names']
      @enable_auto_anti_affinity = openstack_properties['enable_auto_anti_affinity']
      @use_config_drive = !!openstack_properties.fetch('config_drive', false)
      @config_drive = openstack_properties['config_drive']

      @openstack = Bosh::OpenStackCloud::Openstack.new(@options['openstack'])

      @az_provider = Bosh::OpenStackCloud::AvailabilityZoneProvider.new(
        @openstack,
        openstack_properties['ignore_server_availability_zone'],
      )

      @metadata_lock = Mutex.new

      @instance_type_mapper = Bosh::OpenStackCloud::InstanceTypeMapper.new
    end

    def compute
      @openstack.compute
    end

    def glance
      @openstack.image
    end

    def volume
      @openstack.volume
    end

    def auth_url
      @openstack.auth_url
    end

    def network
      @openstack.network
    end

    ##
    # Creates a new OpenStack Image using stemcell image. It requires access
    # to the OpenStack Glance service.
    #
    # @param [String] image_path Local filesystem path to a stemcell image
    # @param [Hash] cloud_properties CPI-specific properties
    # @option cloud_properties [String] name Stemcell name
    # @option cloud_properties [String] version Stemcell version
    # @option cloud_properties [String] infrastructure Stemcell infrastructure
    # @option cloud_properties [String] disk_format Image disk format
    # @option cloud_properties [String] container_format Image container format
    # @option cloud_properties [optional, String] kernel_file Name of the
    #   kernel image file provided at the stemcell archive
    # @option cloud_properties [optional, String] ramdisk_file Name of the
    #   ramdisk image file provided at the stemcell archive
    # @return [String] OpenStack image UUID of the stemcell
    def create_stemcell(image_path, cloud_properties)
      with_thread_name("create_stemcell(#{image_path}...)") do
        stemcell_creator = StemcellCreator.new(@logger, @openstack, cloud_properties)
        stemcell = stemcell_creator.create(image_path, @stemcell_public_visibility)
        stemcell.id
      end
    end

    ##
    # Deletes a stemcell
    #
    # @param [String] stemcell_id OpenStack image UUID of the stemcell to be
    #   deleted
    # @return [void]
    def delete_stemcell(stemcell_id)
      with_thread_name("delete_stemcell(#{stemcell_id})") do
        @logger.info("Deleting stemcell `#{stemcell_id}'...")

        stemcell = Stemcell.create(@logger, @openstack, stemcell_id)
        stemcell.delete
      end
    end

    ##
    # Creates an OpenStack server and waits until it's in running state
    #
    # @param [String] agent_id UUID for the agent that will be used later on by
    #   the director to locate and talk to the agent
    # @param [String] stemcell_id OpenStack image UUID that will be used to
    #   power on new server
    # @param [Hash] resource_pool cloud specific properties describing the
    #   resources needed for this VM
    # @param [Hash] network_spec list of networks and their settings needed for
    #   this VM
    # @param [optional, Array] disk_locality List of disks that might be
    #   attached to this server in the future, can be used as a placement
    #   hint (i.e. server will only be created if resource pool availability
    #   zone is the same as disk availability zone)
    # @param [optional, Hash] environment Data to be merged into agent settings
    # @return [String] OpenStack server UUID
    def create_vm(agent_id, stemcell_id, resource_pool,
                  network_spec = nil, disk_locality = nil, environment = nil)
      with_thread_name("create_vm(#{agent_id}, ...)") do
        @logger.info('Creating new server...')
        registry_key = "vm-#{generate_unique_name}"
        server_params = {
          name: registry_key,
          os_scheduler_hints: resource_pool['scheduler_hints'],
          config_drive: @use_config_drive,
        }

        network_configurator = NetworkConfigurator.new(network_spec, resource_pool['allowed_address_pairs'])
        picked_security_groups = pick_security_groups(server_params, network_configurator, ResourcePool.security_groups(resource_pool))
        pick_stemcell(server_params, stemcell_id)
        flavor = pick_flavor(server_params, resource_pool)
        pick_key_name(server_params, resource_pool)

        @logger.debug("Using scheduler hints: `#{resource_pool['scheduler_hints']}'") if resource_pool['scheduler_hints']

        pick_availability_zone(server_params, disk_locality, resource_pool['availability_zone'])
        configure_volumes(server_params, flavor, resource_pool)

        pick_server_groups(server_params, environment)

        availability_zone = @az_provider.select(disk_locality, resource_pool['availability_zone'])
        server_params[:availability_zone] = availability_zone if availability_zone

        begin
          @openstack.with_openstack { network_configurator.prepare(@openstack, picked_security_groups.map(&:id)) }
          nics = pick_nics(server_params, network_configurator)
          server = create_server(server_params, nics)
          configure_server(network_configurator, server)

          server_tags = {}
          tag_server(server_tags, server, registry_key, network_spec, resource_pool.fetch('loadbalancer_pools', []))

          update_server_settings(server, registry_key, agent_id, network_configurator.network_spec, environment,
                                 flavor_has_ephemeral_disk?(flavor))

          server.id.to_s
        rescue StandardError => e
          begin
            destroy_server(server, server_tags) if server
          rescue StandardError => destroy_err
            @logger.warn("Failed to destroy server: #{destroy_err.message}")
          end

          begin
            @openstack.with_openstack {
              network_configurator.cleanup(@openstack)
            }
          rescue StandardError => cleanup_error
            @logger.warn("Failed to cleanup network resources: #{cleanup_error.message}")
          end
          raise e
        end
      end
    end

    ##
    # Terminates an OpenStack server and waits until it reports as terminated
    #
    # @param [String] server_id OpenStack server UUID
    # @return [void]
    def delete_vm(server_id)
      with_thread_name("delete_vm(#{server_id})") do
        @logger.info("Deleting server `#{server_id}'...")
        server = @openstack.with_openstack { @openstack.compute.servers.get(server_id) }
        if server
          server_tags = metadata_to_tags(server.metadata)
          @logger.debug("Server tags: `#{server_tags}' found for server #{server_id}")
          destroy_server(server, server_tags)
        else
          @logger.info("Server `#{server_id}' not found. Skipping.")
        end
      end
    end

    ##
    # Checks if an OpenStack server exists
    #
    # @param [String] server_id OpenStack server UUID
    # @return [Boolean] True if the vm exists
    def has_vm?(server_id)
      with_thread_name("has_vm?(#{server_id})") do
        server = @openstack.with_openstack { @openstack.compute.servers.get(server_id) }
        !server.nil? && !%i[terminated deleted].include?(server.state.downcase.to_sym)
      end
    end

    ##
    # Reboots an OpenStack Server
    #
    # @param [String] server_id OpenStack server UUID
    # @return [void]
    def reboot_vm(server_id)
      with_thread_name("reboot_vm(#{server_id})") do
        server = @openstack.with_openstack { @openstack.compute.servers.get(server_id) }
        cloud_error("Server `#{server_id}' not found") unless server

        soft_reboot(server)
      end
    end

    ##
    # Configures networking on existing OpenStack server
    #
    # @param [String] server_id OpenStack server UUID
    # @param [Hash] network_spec Raw network spec passed by director
    # @return [void]
    # @raise [Bosh::Clouds:NotSupported] If there's a network change that requires the recreation of the VM
    def configure_networks(server_id, network_spec)
      with_thread_name("configure_networks(#{server_id}, ...)") do
        raise Bosh::Clouds::NotSupported,
              format('network configuration change requires VM recreation: %s', network_spec)
      end
    end

    ##
    # Creates a new OpenStack volume
    #
    # @param [Integer] size disk size in MiB
    # @param [optional, String] server_id OpenStack server UUID of the VM that
    #   this disk will be attached to
    # @return [String] OpenStack volume UUID
    def create_disk(size, cloud_properties, server_id = nil)
      volume_service_client = @openstack.volume
      with_thread_name("create_disk(#{size}, #{cloud_properties}, #{server_id})") do
        raise ArgumentError, 'Disk size needs to be an integer' unless size.is_a?(Integer)
        cloud_error('Minimum disk size is 1 GiB') if size < 1024

        unique_name = generate_unique_name
        volume_params = {
          # cinder v1 requires display_ prefix
          display_name: "volume-#{unique_name}",
          display_description: '',
          # cinder v2 does not require prefix
          name: "volume-#{unique_name}",
          description: '',
          size: mib_to_gib(size),
        }

        if cloud_properties.key?('type')
          volume_params[:volume_type] = cloud_properties['type']
        elsif !@default_volume_type.nil?
          volume_params[:volume_type] = @default_volume_type
        end

        if server_id && @az_provider.constrain_to_server_availability_zone?
          server = @openstack.with_openstack { @openstack.compute.servers.get(server_id) }
          volume_params[:availability_zone] = server.availability_zone if server&.availability_zone
        end

        @logger.info('Creating new volume...')
        new_volume = @openstack.with_openstack { volume_service_client.volumes.create(volume_params) }

        @logger.info("Creating new volume `#{new_volume.id}'...")
        @openstack.wait_resource(new_volume, :available)

        new_volume.id.to_s
      end
    end

    ##
    # Check whether an OpenStack volume exists or not
    #
    # @param [String] disk_id OpenStack volume UUID
    # @return [bool] whether the specific disk is there or not
    def has_disk?(disk_id)
      with_thread_name("has_disk?(#{disk_id})") do
        @logger.info("Check the presence of disk with id `#{disk_id}'...")
        volume = @openstack.with_openstack { @openstack.volume.volumes.get(disk_id) }

        !volume.nil?
      end
    end

    ##
    # Deletes an OpenStack volume
    #
    # @param [String] disk_id OpenStack volume UUID
    # @return [void]
    # @raise [Bosh::Clouds::CloudError] if disk is not in available state
    def delete_disk(disk_id)
      with_thread_name("delete_disk(#{disk_id})") do
        @logger.info("Deleting volume `#{disk_id}'...")
        volume = @openstack.with_openstack { @openstack.volume.volumes.get(disk_id) }
        if volume
          state = volume.status
          cloud_error("Cannot delete volume `#{disk_id}', state is #{state}") if state.to_sym != :available

          @openstack.with_openstack { volume.destroy }
          @openstack.wait_resource(volume, :deleted, :status, true)
        else
          @logger.info("Volume `#{disk_id}' not found. Skipping.")
        end
      end
    end

    ##
    # Attaches an OpenStack volume to an OpenStack server
    #
    # @param [String] server_id OpenStack server UUID
    # @param [String] disk_id OpenStack volume UUID
    # @return [void]
    def attach_disk(server_id, disk_id)
      with_thread_name("attach_disk(#{server_id}, #{disk_id})") do
        server = @openstack.with_openstack { @openstack.compute.servers.get(server_id) }
        cloud_error("Server `#{server_id}' not found") unless server

        volume = @openstack.with_openstack { @openstack.volume.volumes.get(disk_id) }
        cloud_error("Volume `#{disk_id}' not found") unless volume

        device_name = attach_volume(server, volume)

        update_agent_settings(server) do |settings|
          settings['disks'] ||= {}
          settings['disks']['persistent'] ||= {}
          settings['disks']['persistent'][disk_id] = device_name
        end
      end
    end

    ##
    # Detaches an OpenStack volume from an OpenStack server
    #
    # @param [String] server_id OpenStack server UUID
    # @param [String] disk_id OpenStack volume UUID
    # @return [void]
    def detach_disk(server_id, disk_id)
      with_thread_name("detach_disk(#{server_id}, #{disk_id})") do
        server = @openstack.with_openstack { @openstack.compute.servers.get(server_id) }
        cloud_error("Server `#{server_id}' not found") unless server

        volume = @openstack.with_openstack { @openstack.volume.volumes.get(disk_id) }
        if volume.nil?
          @logger.info("Disk `#{disk_id}' not found while trying to detach it from vm `#{server_id}'...")
        else
          detach_volume(server, volume)
        end

        update_agent_settings(server) do |settings|
          settings['disks'] ||= {}
          settings['disks']['persistent'] ||= {}
          settings['disks']['persistent'].delete(disk_id)
        end
      end
    end

    ##
    # Takes a snapshot of an OpenStack volume
    #
    # @param [String] disk_id OpenStack volume UUID
    # @param [Hash] metadata Metadata key/value pairs to add to snapshot
    # @return [String] OpenStack snapshot UUID
    # @raise [Bosh::Clouds::CloudError] if volume is not found
    def snapshot_disk(disk_id, metadata)
      with_thread_name("snapshot_disk(#{disk_id})") do
        metadata = Hash[metadata.map { |key, value| [key.to_s, value] }]
        volume = @openstack.with_openstack { @openstack.volume.volumes.get(disk_id) }
        cloud_error("Volume `#{disk_id}' not found") unless volume

        devices = []
        volume.attachments.each { |attachment| devices << attachment['device'] unless attachment.empty? }

        description = %w[deployment job index].collect { |key| metadata[key] }
        description << devices.first.split('/').last unless devices.empty?
        name = "snapshot-#{generate_unique_name}"
        snapshot_params = {
          # cinder v1 requires display_ prefix
          display_name: name,
          display_description: description.join('/'),
          # cinder v2 does not require prefix
          name: name,
          description: description.join('/'),
          volume_id: volume.id,
          force: true,
        }

        @logger.info("Creating new snapshot for volume `#{disk_id}'...")
        snapshot = @openstack.volume.snapshots.new(snapshot_params)
        @openstack.with_openstack {
          snapshot.save
        }

        @logger.info("Creating new snapshot `#{snapshot.id}' for volume `#{disk_id}'...")
        @openstack.wait_resource(snapshot, :available)

        metadata.merge!(
          'director' => metadata['director_name'],
          'instance_index' => metadata['index'].to_s,
          'instance_name' => metadata['job'] + '/' + metadata['instance_id'],
        )

        metadata.delete('director_name')
        metadata.delete('index')
        metadata.delete('job')

        @logger.info("Creating metadata for snapshot `#{snapshot.id}'...")
        @openstack.with_openstack {
          TagManager.tag_snapshot(snapshot, metadata)
        }

        snapshot.id.to_s
      end
    end

    ##
    # Deletes an OpenStack volume snapshot
    #
    # @param [String] snapshot_id OpenStack snapshot UUID
    # @return [void]
    # @raise [Bosh::Clouds::CloudError] if snapshot is not in available state
    def delete_snapshot(snapshot_id)
      with_thread_name("delete_snapshot(#{snapshot_id})") do
        @logger.info("Deleting snapshot `#{snapshot_id}'...")
        snapshot = @openstack.with_openstack { @openstack.volume.snapshots.get(snapshot_id) }
        if snapshot
          state = snapshot.status
          cloud_error("Cannot delete snapshot `#{snapshot_id}', state is #{state}") if state.to_sym != :available

          @openstack.with_openstack { snapshot.destroy }
          @openstack.wait_resource(snapshot, :deleted, :status, true)
        else
          @logger.info("Snapshot `#{snapshot_id}' not found. Skipping.")
        end
      end
    end

    ##
    # Set metadata for an OpenStack server
    #
    # @param [String] server_id OpenStack server UUID
    # @param [Hash] metadata Metadata key/value pairs
    # @return [void]
    def set_vm_metadata(server_id, metadata)
      with_thread_name("set_vm_metadata(#{server_id}, ...)") do
        @openstack.with_openstack do
          server = @openstack.compute.servers.get(server_id)
          cloud_error("Server `#{server_id}' not found") unless server

          TagManager.tag_server(server, metadata)

          if server.metadata.get(REGISTRY_KEY_TAG)
            name = metadata['name']
            job = metadata['job']
            index = metadata['index']
            compiling = metadata['compiling']
            if name
              @logger.debug("Rename VM with id '#{server_id}' to '#{name}'")
              @openstack.compute.update_server(server_id, 'name' => name.to_s)
            elsif job && index
              @logger.debug("Rename VM with id '#{server_id}' to '#{job}/#{index}'")
              @openstack.compute.update_server(server_id, 'name' => "#{job}/#{index}")
            elsif compiling
              @logger.debug("Rename VM with id '#{server_id}' to 'compiling/#{compiling}'")
              @openstack.compute.update_server(server_id, 'name' => "compiling/#{compiling}")
            end
          else
            @logger.debug("VM with id '#{server_id}' has no 'registry_key' tag")
          end
        end
      end
    end

    ##
    # Set metadata for an OpenStack disk
    #
    # @param [String] disk_id OpenStack disk UUID
    # @param [Hash] metadata Metadata key/value pairs
    # @return [void]
    def set_disk_metadata(disk_id, metadata)
      with_thread_name("set_disk_metadata(#{disk_id}, ...)") do
        @openstack.with_openstack do
          disk = @openstack.volume.volumes.get(disk_id)
          cloud_error("Disk `#{disk_id}' not found") unless disk
          TagManager.tag_volume(@openstack.volume, disk_id, metadata)
        end
      end
    end

    # Map a set of cloud agnostic VM properties (cpu, ram, ephemeral_disk_size) to
    # a set of OpenStack specific cloud_properties
    # @param [Hash] requirements requested cpu, ram, and ephemeral_disk_size
    # @return [Hash] OpenStack specific cloud_properties describing instance (e.g. instance_type)
    def calculate_vm_cloud_properties(requirements)
      required_keys = %w[cpu ram ephemeral_disk_size]
      missing_keys = required_keys.reject { |key| requirements[key] }
      unless missing_keys.empty?
        missing_keys.map! { |k| "'#{k}'" }
        raise "Missing VM cloud properties: #{missing_keys.join(', ')}"
      end

      @instance_type_mapper.map(
        requirements: requirements,
        flavors: compute.flavors,
        boot_from_volume: @boot_from_volume,
      )
    end

    ##
    # Selects the availability zone to use from a list of disk volumes,
    # resource pool availability zone (if any) and the default availability
    # zone.
    #
    # @param [Array] volumes OpenStack volume UUIDs to attach to the vm
    # @param [String] resource_pool_az availability zone specified in
    #   the resource pool (may be nil)
    # @return [String] availability zone to use or nil
    # @note this is a private method that is public to make it easier to test
    def select_availability_zone(volumes, resource_pool_az)
      @az_provider.select(volumes, resource_pool_az)
    end

    def is_v3
      @options['openstack']['auth_url'].match(/\/v3(?=\/|$)/)
    end

    ##
    # Updates the agent settings
    #
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server
    def update_agent_settings(server)
      raise ArgumentError, 'Block is not provided' unless block_given?
      registry_key = registry_key_for(server)
      @logger.info("Updating settings for server `#{server.id}' with registry key `#{registry_key}'...")
      settings = @registry.read_settings(registry_key)
      yield settings
      @registry.update_settings(registry_key, settings)
    end

    # Information about Openstack CPI, currently supported stemcell formats
    # @return [Hash] Openstack CPI properties
    def info
      { 'stemcell_formats' => ['openstack-raw', 'openstack-qcow2', 'openstack-light'] }
    end

    ##
    # Resizes an existing OpenStack volume
    #
    # @param [String] disk_id volume Cloud ID
    # @param [Integer] new_size disk size in MiB
    def resize_disk(disk_id, new_size)
      new_size_gib = mib_to_gib(new_size)

      with_thread_name("resize_disk(#{disk_id}, #{new_size_gib})") do
        @logger.info("Resizing volume `#{disk_id}'...")
        @openstack.with_openstack do
          volume = @openstack.volume.volumes.get(disk_id)
          cloud_error("Cannot resize volume because volume with #{disk_id} not found") unless volume
          actual_size_gib = volume.size
          if actual_size_gib == new_size_gib
            @logger.info("Skipping resize of disk #{disk_id} because current value #{actual_size_gib} GiB is equal new value #{new_size_gib} GiB")
          elsif actual_size_gib > new_size_gib
            not_supported_error("Cannot resize volume to a smaller size from #{actual_size_gib} GiB to #{new_size_gib} GiB") if actual_size_gib > new_size_gib
          else
            attachments = volume.attachments
            cloud_error("Cannot resize volume '#{disk_id}' it still has #{attachments.size} attachment(s)") unless attachments.empty?
            volume.extend(new_size_gib)
            @logger.info("Resizing #{disk_id} from #{actual_size_gib} GiB to #{new_size_gib} GiB")
            @openstack.wait_resource(volume, :available)
            @logger.info("Disk #{disk_id} resized from #{actual_size_gib} GiB to #{new_size_gib} GiB")
          end
        end
      end

      nil
    end

    private

    def pick_security_groups(server_params, network_configurator, resource_pool_groups)
      network_configurator.check_preconditions(@openstack.use_nova_networking?, @use_config_drive, @use_dhcp)

      picked_security_groups = SecurityGroups.select_and_retrieve(
        @openstack,
        @default_security_groups,
        network_configurator.security_groups,
        resource_pool_groups,
      )
      @logger.debug("Using security groups: `#{picked_security_groups.map(&:name).join(', ')}'")
      server_params[:security_groups] = picked_security_groups.map(&:name)
      picked_security_groups
    end

    def pick_key_name(server_params, resource_pool)
      keyname = resource_pool['key_name'] || @default_key_name
      validate_key_exists(keyname)
      server_params[:key_name] = keyname
    end

    def pick_flavor(server_params, resource_pool)
      flavor = @openstack.with_openstack { @openstack.compute.flavors.find { |f| f.name == resource_pool['instance_type'] } }
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

    def pick_stemcell(server_params, stemcell_id)
      stemcell = Stemcell.create(@logger, @openstack, stemcell_id)
      stemcell.validate_existence
      server_params[:image_ref] = stemcell.image_id
    end

    def pick_availability_zone(server_params, disk_locality, resource_pool_zone)
      availability_zone = @az_provider.select(disk_locality, resource_pool_zone)
      server_params[:availability_zone] = availability_zone if availability_zone
    end

    def configure_volumes(server_params, flavor, resource_pool)
      volume_configurator = Bosh::OpenStackCloud::VolumeConfigurator.new(@logger)
      return unless volume_configurator.boot_from_volume?(@boot_from_volume, resource_pool)

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

    def pick_server_groups(server_params, environment)
      return unless @enable_auto_anti_affinity
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

    def pick_nics(server_params, network_configurator)
      nics = network_configurator.nics
      @logger.debug("Using NICs: `#{nics.join(', ')}'")
      server_params[:nics] = nics
      server_params[:user_data] = JSON.dump(user_data(server_params[:name], network_configurator.network_spec))
      nics
    end

    def create_server(server_params, nics)
      @logger.debug("Using boot parms: `#{Bosh::Cpi::Redactor.clone_and_redact(server_params, 'user_data').inspect}'")
      server = @openstack.with_openstack do
        begin
          @openstack.compute.servers.create(server_params)
        rescue Excon::Error::Timeout => e
          @logger.debug(e.backtrace)
          cloud_error_message = "VM creation with name '#{server_params[:name]}' received a timeout. " \
                                "The VM might still have been created by OpenStack.\nOriginal message: "
          raise Bosh::Clouds::VMCreationFailed.new(false), cloud_error_message + e.message
        rescue Excon::Error::BadRequest, Excon::Error::NotFound, Fog::Compute::OpenStack::NotFound => e
          raise e if @openstack.use_nova_networking?
          not_existing_net_ids = not_existing_net_ids(nics)
          raise e if not_existing_net_ids.empty?
          @logger.debug(e.backtrace)
          cloud_error_message = "VM creation with name '#{server_params[:name]}' failed. Following network " \
                                "IDs are not existing or not accessible from this project: '#{not_existing_net_ids.join(',')}'. " \
                                'Make sure you do not use subnet IDs'
          raise Bosh::Clouds::VMCreationFailed.new(false), cloud_error_message
        rescue Excon::Error::Forbidden => e
          raise e unless e.message.include? 'Quota exceeded, too many servers in group'
          raise Bosh::Clouds::CloudError, "You have reached your quota for members in a server group for project '#{@openstack.params[:openstack_tenant]}'. Please disable auto-anti-affinity server groups or increase your quota."
        end
      end
      server
    end

    def configure_server(network_configurator, server)
      @logger.info("Creating new server `#{server.id}'...")
      begin
        @openstack.wait_resource(server, :active, :state)

        @logger.info("Configuring network for server `#{server.id}'...")
        @openstack.with_openstack { network_configurator.configure(@openstack, server) }
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

    def update_server_settings(server, registry_key, agent_id, network_spec, environment, ephemeral_disk)
      settings = initial_agent_settings(registry_key, agent_id, network_spec, environment, ephemeral_disk)
      @logger.info("Updating settings for server `#{server.id}'...")
      @registry.update_settings(registry_key, settings)
    rescue StandardError => e
      @logger.warn("Failed to register server: #{e.message}")
      raise Bosh::Clouds::VMCreationFailed.new(false), e.message
    end

    def mib_to_gib(size)
      (size / 1024.0).ceil
    end

    def registry_key_for(server)
      registry_key_metadatum = @openstack.with_openstack { server.metadata.get(REGISTRY_KEY_TAG) }
      registry_key_metadatum ? registry_key_metadatum.value : server.name
    end

    def not_existing_net_ids(nics)
      result = []
      begin
        network = @openstack.network
        nics.each do |nic|
          if nic['net_id']
            result << nic['net_id'] unless network.networks.get(nic['net_id'])
          end
        end
      rescue StandardError => e
        @logger.warn(e.backtrace)
      end
      result
    end

    ##
    # Generates an unique name
    #
    # @return [String] Unique name
    def generate_unique_name
      SecureRandom.uuid
    end

    ##
    # Prepare server user data
    #
    # @param [String] registry_key used by agent to look up settings from registry
    # @param [Hash] network_spec network specification
    # @return [Hash] server user data
    def user_data(registry_key, network_spec, public_key = nil)
      data = {}

      data['registry'] = { 'endpoint' => @registry.endpoint }
      data['server'] = { 'name' => registry_key }
      data['openssh'] = { 'public_key' => public_key } if public_key
      data['networks'] = agent_network_spec(network_spec)

      with_dns(network_spec) do |servers|
        data['dns'] = { 'nameserver' => servers }
      end

      data
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
          return
        end
      end
    end

    ##
    # Generates initial agent settings. These settings will be read by Bosh Agent from Bosh Registry on a target
    # server. Disk conventions in Bosh Agent for OpenStack are:
    # - system disk: /dev/sda
    # - ephemeral disk: /dev/sdb
    # - persistent disks: /dev/sdc through /dev/sdz
    # As some kernels remap device names (from sd* to vd* or xvd*), Bosh Agent will lookup for the proper device name
    #
    # @param [String] uuid Initial uuid
    # @param [String] agent_id Agent id (will be picked up by agent to
    #   assume its identity
    # @param [Hash] network_spec Agent network spec
    # @param [Hash] environment Environment settings
    # @param [Boolean] has_ephemeral Has Ephemeral disk?
    # @return [Hash] Agent settings
    def initial_agent_settings(uuid, agent_id, network_spec, environment, has_ephemeral)
      settings = {
        'vm' => {
          'name' => uuid,
        },
        'agent_id' => agent_id,
        'networks' => agent_network_spec(network_spec),
        'disks' => {
          'system' => '/dev/sda',
          'persistent' => {},
        },
      }

      settings['disks']['ephemeral'] = has_ephemeral ? '/dev/sdb' : nil
      settings['env'] = environment if environment
      settings.merge(@agent_properties)
    end

    def agent_network_spec(network_spec)
      network_spec.map do |name, settings|
        settings['use_dhcp'] = @use_dhcp unless settings['type'] == 'vip'
        [name, settings]
      end.to_h
    end

    ##
    # Soft reboots an OpenStack server
    #
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server
    # @return [void]
    def soft_reboot(server)
      @logger.info("Soft rebooting server `#{server.id}'...")
      @openstack.with_openstack { server.reboot }
      @openstack.wait_resource(server, :active, :state)
    end

    ##
    # Hard reboots an OpenStack server
    #
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server
    # @return [void]
    def hard_reboot(server)
      @logger.info("Hard rebooting server `#{server.id}'...")
      @openstack.with_openstack { server.reboot(type = 'HARD') }
      @openstack.wait_resource(server, :active, :state)
    end

    ##
    # Attaches an OpenStack volume to an OpenStack server
    #
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server
    # @param [Fog::Compute::OpenStack::Volume] volume OpenStack volume
    # @return [String] Device name
    def attach_volume(server, volume)
      @logger.info("Attaching volume `#{volume.id}' to server `#{server.id}'...")
      volume_attachments = @openstack.with_openstack { server.volume_attachments }
      device = volume_attachments.find { |a| a['volumeId'] == volume.id }

      if device.nil?
        device_name = select_device_name(volume_attachments, first_device_name_letter(server))
        cloud_error('Server has too many disks attached') if device_name.nil?

        @logger.info("Attaching volume `#{volume.id}' to server `#{server.id}', device name is `#{device_name}'")
        @openstack.with_openstack { server.attach_volume(volume.id, device_name) }
        @openstack.wait_resource(volume, :'in-use')
      else
        device_name = device['device']
        @logger.info("Volume `#{volume.id}' is already attached to server `#{server.id}' in `#{device_name}'. Skipping.")
      end

      device_name
    end

    ##
    # Select the first available device name
    #
    # @param [Array] volume_attachments Volume attachments
    # @param [String] first_device_name_letter First available letter for device names
    # @return [String] First available device name or nil is none is available
    def select_device_name(volume_attachments, first_device_name_letter)
      (first_device_name_letter..'z').each do |char|
        # Some kernels remap device names (from sd* to vd* or xvd*).
        device_names = ["/dev/sd#{char}", "/dev/vd#{char}", "/dev/xvd#{char}"]
        # Bosh Agent will lookup for the proper device name if we set it initially to sd*.
        return "/dev/sd#{char}" if volume_attachments.select { |v| device_names.include?(v['device']) }.empty?
        @logger.warn("`/dev/sd#{char}' is already taken")
      end

      nil
    end

    ##
    # Returns the first letter to be used on device names
    #
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server
    # @return [String] First available letter
    def first_device_name_letter(server)
      letter = FIRST_DEVICE_NAME_LETTER.dup
      return letter if server.flavor.nil?
      return letter unless server.flavor.key?('id')
      flavor = @openstack.with_openstack { @openstack.compute.flavors.find { |f| f.id == server.flavor['id'] } }
      return letter if flavor.nil?

      letter.succ! if flavor_has_ephemeral_disk?(flavor)
      letter.succ! if flavor_has_swap_disk?(flavor)
      letter.succ! if @config_drive == 'disk'
      letter
    end

    ##
    # Detaches an OpenStack volume from an OpenStack server
    #
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server
    # @param [Fog::Compute::OpenStack::Volume] volume OpenStack volume
    # @return [void]
    def detach_volume(server, volume)
      @logger.info("Detaching volume `#{volume.id}' from `#{server.id}'...")
      volume_attachments = @openstack.with_openstack { server.volume_attachments }
      attachment = volume_attachments.find { |a| a['volumeId'] == volume.id }
      if attachment
        @openstack.with_openstack { server.detach_volume(volume.id) }
        @openstack.wait_resource(volume, :available)
      else
        @logger.info("Disk `#{volume.id}' is not attached to server `#{server.id}'. Skipping.")
      end
    end

    ##
    # Checks if the OpenStack flavor has ephemeral disk
    #
    # @param [Fog::Compute::OpenStack::Flavor] OpenStack flavor
    # @return [Boolean] true if flavor has ephemeral disk, false otherwise
    def flavor_has_ephemeral_disk?(flavor)
      flavor.ephemeral && flavor.ephemeral.to_i > 0
    end

    ##
    # Checks if the OpenStack flavor has swap disk
    #
    # @param [Fog::Compute::OpenStack::Flavor] OpenStack flavor
    # @return [Boolean] true if flavor has swap disk, false otherwise
    def flavor_has_swap_disk?(flavor)
      flavor.swap.nil? || flavor.swap.to_i <= 0 ? false : true
    end

    ##
    # Checks if options passed to CPI are valid and can actually
    # be used to create all required data structures etc.
    #
    # @return [void]
    # @raise [ArgumentError] if options are not valid
    def validate_options
      raise ArgumentError, "Invalid OpenStack cloud properties: No 'openstack' properties specified." unless @options['openstack']
      auth_url = @options['openstack']['auth_url']
      schema = Membrane::SchemaParser.parse do
        openstack_options_schema = {
          'openstack' => {
            'auth_url' => String,
            'username' => String,
            'api_key' => String,
            optional('region') => String,
            optional('endpoint_type') => String,
            optional('state_timeout') => Numeric,
            optional('stemcell_public_visibility') => bool,
            optional('connection_options') => Hash,
            optional('boot_from_volume') => bool,
            optional('default_key_name') => String,
            optional('default_security_groups') => [String],
            optional('default_volume_type') => String,
            optional('wait_resource_poll_interval') => Integer,
            optional('config_drive') => enum('disk', 'cdrom'),
            optional('human_readable_vm_names') => bool,
            optional('use_dhcp') => bool,
            optional('use_nova_networking') => bool,
          },
          'registry' => {
            'endpoint' => String,
            'user' => String,
            'password' => String,
          },
          optional('agent') => Hash,
        }
        if Bosh::OpenStackCloud::Openstack.is_v3(auth_url)
          openstack_options_schema['openstack']['project'] = String
          openstack_options_schema['openstack']['domain'] = String
        else
          openstack_options_schema['openstack']['tenant'] = String
          openstack_options_schema['openstack'][optional('domain')] = String
        end
        openstack_options_schema
      end
      schema.validate(@options)
    rescue Membrane::SchemaValidationError => e
      raise ArgumentError, "Invalid OpenStack cloud properties: #{e.inspect}"
    end

    def initialize_registry
      registry_properties = @options.fetch('registry')
      registry_endpoint   = registry_properties.fetch('endpoint')
      registry_user       = registry_properties.fetch('user')
      registry_password   = registry_properties.fetch('password')

      @registry = Bosh::Cpi::RegistryClient.new(registry_endpoint,
                                                registry_user,
                                                registry_password)
    end

    def normalize_options(options)
      raise ArgumentError, "Invalid OpenStack cloud properties: Hash expected, received #{options}" unless options.is_a?(Hash)
      # we only care about two top-level fields
      options = hash_filter(options.dup) { |key| OPTION_KEYS.include?(key) }
      # nil values should be treated the same as missing keys (makes validating optional fields easier)
      delete_entries_with_nil_keys(options)
    end

    def hash_filter(hash)
      copy = {}
      hash.each do |key, value|
        copy[key] = value if yield(key)
      end
      copy
    end

    def delete_entries_with_nil_keys(options)
      options.each do |key, value|
        if value.nil?
          options.delete(key)
        elsif value.is_a?(Hash)
          options[key] = delete_entries_with_nil_keys(value.dup)
        end
      end
      options
    end

    def destroy_server(server, server_tags)
      server_tags ||= {}
      server_port_ids = NetworkConfigurator.port_ids(@openstack, server.id)
      @logger.debug("Network ports: `#{server_port_ids.join(', ')}' found for server #{server.id}")
      bosh_group = "#{server_tags['director']}-#{server_tags['deployment']}-#{server_tags['instance_group']}"

      lbaas_error = catch_error('Removing lbaas pool memberships') { LoadbalancerConfigurator.new(@openstack, @logger).cleanup_memberships(server_tags) }
      @openstack.with_openstack { server.destroy }
      fail_on_error(
        catch_error('Wait for server deletion') { @openstack.wait_resource(server, %i[terminated deleted], :state, true) },
        catch_error('Removing ports') { NetworkConfigurator.cleanup_ports(@openstack, server_port_ids) },
        catch_error('Delete server group if empty') { ServerGroups.new(@openstack).delete_if_no_members(Bosh::Clouds::Config.uuid, bosh_group) },
        lbaas_error,
        catch_error('Deleting registry settings') {
          registry_key = server_tags.fetch(REGISTRY_KEY_TAG.to_s, server.name)
          @logger.info("Deleting settings for server `#{server.id}' with registry_key `#{registry_key}' ...")
          @registry.delete_settings(registry_key)
        },
      )
    end

    def validate_key_exists(keyname)
      keypair = @openstack.with_openstack { @openstack.compute.key_pairs.find { |k| k.name == keyname } }
      cloud_error("Key-pair `#{keyname}' not found") if keypair.nil?
      @logger.debug("Using key-pair: `#{keypair.name}' (#{keypair.fingerprint})")
    end

    def metadata_to_tags(fog_metadata)
      fog_metadata.map { |metadatum| [metadatum.key, metadatum.value] }.to_h
    end
  end
end
