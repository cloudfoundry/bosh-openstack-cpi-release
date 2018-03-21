module Bosh::OpenStackCloud
  class VolumeConfigurator
    include Helpers

    def initialize(logger)
      @logger = logger
    end

    def select_boot_volume_size(flavor, resource_pool)
      if resource_pool['root_disk'].nil?
        if flavor.disk == 0
          cloud_error("Flavor '#{flavor.name}' has a root disk size of 0. Either pick a different flavor or define root_disk.size in your VM cloud_properties")
        end

        flavor.disk
      else
        root_disk_size = resource_pool['root_disk']['size']
        raise ArgumentError, 'Minimum root_disk size is 1 GiB' if root_disk_size.nil? || root_disk_size < 1
        @logger.debug("Using root_disk of size '#{root_disk_size}', instead of flavor.disk")

        root_disk_size
      end
    end

    def boot_from_volume?(boot_from_volume, resource_pool)
      return boot_from_volume if resource_pool['boot_from_volume'].nil?

      resource_pool['boot_from_volume']
    end
  end
end
