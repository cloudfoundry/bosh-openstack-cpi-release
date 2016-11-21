module Bosh::OpenStackCloud
  class StemcellFinder
    include Helpers

    def initialize(logger, openstack)
      @logger = logger
      @openstack = openstack
    end

    def by_id(id)
      regex = / light$/

      if id =~ regex
        image = find_image(id.gsub(regex, ''))
        LightStemcell.new(@logger, image.id)
      else
        image = find_image(id)
        Stemcell.new(@logger, @openstack, image.id)
      end
    end

    private

    def find_image(stemcell_id)
      image = with_openstack { @openstack.image.images.find_by_id(stemcell_id) }
      cloud_error("Image `#{stemcell_id}' not found") if image.nil?
      @logger.debug("Using image: `#{stemcell_id}'")
      image
    end
  end
end