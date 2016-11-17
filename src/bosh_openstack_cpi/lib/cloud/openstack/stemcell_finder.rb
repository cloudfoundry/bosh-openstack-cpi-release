module Bosh::OpenStackCloud
  class StemcellFinder
    include Helpers

    def initialize(logger, openstack)
      @logger = logger
      @openstack = openstack
    end

    def by_id(id)
      heavy_stemcell_id = id.gsub(/ light$/, '')

      image = with_openstack { @openstack.image.images.find_by_id(heavy_stemcell_id) }
      cloud_error("Image `#{heavy_stemcell_id}' not found") if image.nil?
      @logger.debug("Using image: `#{heavy_stemcell_id}'")
      image
    end
  end
end