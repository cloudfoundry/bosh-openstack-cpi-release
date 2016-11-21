module Bosh::OpenStackCloud
  class Stemcell
    include Helpers

    attr_reader :id, :image_id

    def initialize(logger, openstack, id)
      @id = id
      @image_id = id
      @openstack = openstack
      @logger = logger
    end

    def delete
      image = with_openstack { @openstack.image.images.find_by_id(image_id) }
      if image
        with_openstack { image.destroy }
        @logger.info("Stemcell `#{image_id}' is now deleted")
      else
        @logger.info("Stemcell `#{image_id}' not found. Skipping.")
      end
    end

  end

  class LightStemcell
    attr_reader :id, :image_id

    def initialize(logger, id)
      @id = "#{id} light"
      @image_id = id
      @logger = logger
    end

    def delete
      @logger.info("NoOP: Deleting light stemcell '#{id}'")
    end
  end
end