module Bosh::OpenStackCloud
  class AvailabilityZoneProvider
    include Helpers

    def initialize(openstack, ignore_server_availability_zone)
      @openstack = openstack
      @ignore_server_availability_zone = ignore_server_availability_zone
    end

    def select(volume_ids, resource_pool_az)
      if volume_ids && !volume_ids.empty? && constrain_to_server_availability_zone?
        fog_volume_map = @openstack.volume.volumes
        volumes = volume_ids.map { |vid| @openstack.with_openstack { fog_volume_map.get(vid) } }
        ensure_same_availability_zone(volumes, resource_pool_az)
        ignore_empty_string(volumes.first.availability_zone)
      else
        resource_pool_az
      end
    end

    def constrain_to_server_availability_zone?
      !@ignore_server_availability_zone
    end

    private

    def ignore_empty_string(string)
      if string
        string unless string.empty?
      end
    end

    ##
    # Ensure all supplied availability zones are the same
    #
    # @param [Array] disks OpenStack volumes
    # @param [String] default availability zone specified in
    #   the resource pool (may be nil)
    # @return [String] availability zone to use or nil
    # @note this is a private method that is public to make it easier to test
    def ensure_same_availability_zone(disks, default)
      zones = disks.map(&:availability_zone)
      zones << default if default
      zones.uniq!
      cloud_error format("can't use multiple availability zones: %s", zones.join(', ')) unless zones.size == 1
    end
  end
end
