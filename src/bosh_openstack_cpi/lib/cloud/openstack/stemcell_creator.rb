module Bosh::OpenStackCloud
  class StemcellCreator
    include Helpers
    def initialize(logger, openstack, cloud_properties)
      @logger = logger
      @openstack = openstack
      @cloud_properties = cloud_properties
    end

    def create(*args)
      creator.create(*args)
    end

    private

    def creator
      if @cloud_properties.key?('image_id')
        LightStemcellCreator.new(@logger, @openstack, @cloud_properties)
      else
        HeavyStemcellCreator.new(@logger, @openstack, @cloud_properties)
      end
    end
  end

  class LightStemcellCreator
    include Helpers
    def initialize(logger, openstack, cloud_properties)
      @logger = logger
      @openstack = openstack
      @cloud_properties = cloud_properties
    end

    def create(_, _)
      image_id = @cloud_properties['image_id']
      @logger.info("Checking for image with id '#{image_id}' referenced by light stemcell")
      image = @openstack.with_openstack(retryable: true) { @openstack.image.images.get(image_id) }
      if !image || image.status != 'active'
        cloud_error("No active image with id '#{image_id}' referenced by light stemcell found in OpenStack.")
      end

      LightStemcell.new(@logger, @openstack, image.id)
    end
  end

  class HeavyStemcellCreator
    include Helpers

    def initialize(logger, openstack, cloud_properties)
      @logger = logger
      @openstack = openstack
      @cloud_properties = cloud_properties
    end

    def set_public_param(image_params, is_public)
      image_params[:visibility] = is_public ? 'public' : 'private'
    end

    def set_image_properties(image_params, image_properties)
      image_params.merge!(image_properties)
    end

    def upload(image_params, image_location)
      image = create_openstack_image(image_params)
      @openstack.wait_resource(image, :queued)
      @logger.info("Performing file upload for image: '#{image.id}'...")
      image.upload_data(File.open(image_location, 'rb'))
      image
    end

    def create(image_path, is_public)
      Dir.mktmpdir do |tmp_dir|
        @logger.info('Creating new image...')

        image_params = {
          name: "#{@cloud_properties['name']}/#{@cloud_properties['version']}",
          disk_format: @cloud_properties['disk_format'],
          container_format: @cloud_properties['container_format'],
        }

        set_public_param(image_params, is_public)

        image_properties = HeavyStemcellCreator.normalize_image_properties(@cloud_properties)

        set_image_properties(image_params, image_properties)

        @logger.info("Extracting stemcell file to `#{tmp_dir}'...")
        unpack_image(tmp_dir, image_path)

        image_location = File.join(tmp_dir, 'root.img')
        image = upload(image_params, image_location)

        @logger.info("Waiting for image '#{image.id}' to have status 'active'...")
        @openstack.wait_resource(image, :active)

        HeavyStemcell.new(@logger, @openstack, image.id.to_s)
      end
    rescue StandardError => e
      @logger.error(e)
      raise e
    end

    def create_openstack_image(image_params)
      @logger.debug("Using image params: `#{image_params.inspect}'")
      @openstack.with_openstack { @openstack.image.images.create(image_params) }
    end

    def unpack_image(tmp_dir, image_path)
      result = Bosh::Exec.sh("tar -C #{tmp_dir} -xzf #{image_path} 2>&1", on_error: :return)
      if result.failed?
        @logger.error("Extracting stemcell root image failed in dir #{tmp_dir}, " \
          "tar returned #{result.exit_status}, output: #{result.output}")
        cloud_error('Extracting stemcell root image failed. Check task debug log for details.')
      end
      root_image = File.join(tmp_dir, 'root.img')
      cloud_error('Root image is missing from stemcell archive') unless File.exist?(root_image)
    end

    def self.normalize_image_properties(properties)
      image_properties = {}
      image_options = %w[version os_type os_distro architecture auto_disk_config
                         hw_vif_model hw_disk_bus_model hw_scsi_model hw_disk_bus
                         hypervisor_type vmware_adaptertype vmware_disktype
                         vmware_linked_clone vmware_ostype]
      image_options.reject { |image_option| properties[property_option_for_image_option(image_option)].nil? }.each do |image_option|
        image_properties[image_option.to_sym] = properties[property_option_for_image_option(image_option)].to_s
      end
      image_properties
    end

    def self.property_option_for_image_option(image_option)
      if image_option == 'hypervisor_type'
        'hypervisor'
      else
        image_option
      end
    end
  end
end
