module Bosh::OpenStackCloud
  class AvailabilityZoneProvider
    include Helpers

    def initialize(openstack, ignore_server_availability_zone)
      @openstack = openstack
      @ignore_server_availability_zone = ignore_server_availability_zone
    end

    def select(volume_ids, resource_pool_az)
      return resource_pool_az if volume_ids_empty?(volume_ids) || @ignore_server_availability_zone

      volumes = volumes(volume_ids)
      volume_azs = volumes.map(&:availability_zone)
      if resource_pool_az
        all_azs = volume_azs + [resource_pool_az]
        same_availability_zone?(all_azs) ? resource_pool_az : fail_for_different_azs(resource_pool_az, volumes)
      else
        same_availability_zone?(volume_azs) ? first_volume_az(volume_azs): fail_for_different_azs(resource_pool_az, volumes)
      end
    end

    def use_server_availability_zone?
      !@ignore_server_availability_zone
    end

    private

    def first_volume_az(volume_azs)
      volume_azs.first.nil? || volume_azs.first.empty? ? nil : volume_azs.first
    end

    def fail_for_different_azs(resource_pool_az, volumes)
      cloud_error format("can't use multiple availability zones: %s, %s. " +
          "Enable 'openstack.ignore_server_availability_zone' to allow VMs and disks to be in different AZs, or use the same AZ for both.",
          resource_pool_az_description(resource_pool_az), disk_az_description(volumes))
    end

    def volume_ids_empty?(volume_ids)
      volume_ids.nil? || volume_ids.empty?
    end

    def same_availability_zone?(azs)
      uniq_azs = azs.uniq
      uniq_azs.size == 1
    end

    def volumes(volume_ids)
      fog_volume_map = @openstack.volume.volumes
      volume_ids.map {|vid| @openstack.with_openstack {fog_volume_map.get(vid)}}
    end

    def resource_pool_az_description(resource_pool_az)
      if resource_pool_az
        format("VM is created in AZ '%s'", resource_pool_az)
      else
        'VM is created in default AZ'
      end
    end

    def disk_az_description(volumes)
      volumes.map do |volume|
        format("disk '%s' is in AZ '%s'", volume.id, volume.availability_zone)
      end.join(', ')
    end
  end
end
