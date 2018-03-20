module Bosh::OpenStackCloud
  module Stemcell
    include Helpers

    attr_reader :id, :image_id

    def initialize(logger, openstack, id)
      @image_id = id
      @openstack = openstack
      @logger = logger
    end

    def self.create(logger, openstack, id)
      regex = / light$/

      if id.match?(regex)
        LightStemcell.new(logger, openstack, id.gsub(regex, ''))
      else
        HeavyStemcell.new(logger, openstack, id)
      end
    end

    def validate_existence
      image = @openstack.with_openstack { @openstack.image.images.find_by_id(image_id) }
      cloud_error("Image `#{id}' not found") if image.nil?
      @logger.debug("Using image: `#{id}'")
    end
  end

  class HeavyStemcell
    include Stemcell

    def initialize(logger, openstack, id)
      super
      @id = id
    end

    def delete
      image = @openstack.with_openstack { @openstack.image.images.find_by_id(image_id) }
      if image
        @openstack.with_openstack { image.destroy }
        @logger.info("Stemcell `#{image_id}' is now deleted")
      else
        @logger.info("Stemcell `#{image_id}' not found. Skipping.")
      end
    end
  end

  class LightStemcell
    include Stemcell

    def initialize(logger, openstack, id)
      super
      @id = "#{id} light"
    end

    def delete
      @logger.info("NoOP: Deleting light stemcell '#{id}'")
    end
  end
end
