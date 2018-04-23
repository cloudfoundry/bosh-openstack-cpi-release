module Bosh::OpenStackCloud
  class AvailabilityZoneProvider
    include Helpers

    def initialize(openstack, ignore_server_availability_zone)
      @openstack = openstack
      @ignore_server_availability_zone = ignore_server_availability_zone
    end

    def select(volume_ids, resource_pool_az)
      if volume_ids_not_empty?(volume_ids) && use_server_availability_zone?
        azs = volume_azs(volume_ids)
        azs << resource_pool_az if resource_pool_az
        ensure_one_availability_zone(azs)
        azs.first.nil? || azs.first.empty? ? nil : azs.first
      else
        resource_pool_az
      end
    end

    def use_server_availability_zone?
      !@ignore_server_availability_zone
    end

    private

    def volume_ids_not_empty?(volume_ids)
      volume_ids && !volume_ids.empty?
    end

    def volume_azs(volume_ids)
      fog_volume_map = @openstack.volume.volumes
      volumes = volume_ids.map { |vid| @openstack.with_openstack { fog_volume_map.get(vid) } }
      volumes.map(&:availability_zone)
    end

    def ensure_one_availability_zone(azs)
      uniq_azs = azs.uniq
      cloud_error format("can't use multiple availability zones: %s", uniq_azs.join(', ')) unless uniq_azs.size == 1
    end
  end
end
