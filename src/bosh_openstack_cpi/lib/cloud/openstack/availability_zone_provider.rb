module Bosh::OpenStackCloud
  class AvailabilityZoneProvider
    include Helpers

    def initialize(openstack, ignore_server_availability_zone)
      @openstack = openstack
      @ignore_server_availability_zone = ignore_server_availability_zone
    end

    def select(volume_ids, resource_pool_az)
      if volume_ids_not_empty?(volume_ids) && use_server_availability_zone?
        ensure_same_availability_zone(volume_ids, resource_pool_az)
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

    def ensure_same_availability_zone(volume_ids, resource_pool_az)
      fog_volume_map = @openstack.volume.volumes
      volumes = volume_ids.map { |vid| @openstack.with_openstack { fog_volume_map.get(vid) } }
      azs = volumes.map(&:availability_zone)
      azs << resource_pool_az if resource_pool_az

      uniq_azs = azs.uniq
      if uniq_azs.size > 1
        cloud_error format("can't use multiple availability zones: %s, %s. " +
                           "Enable 'openstack.ignore_server_availability_zone' to allow VMs and disks to be in different AZs, or use the same AZ for both.",
                           resource_pool_az_description(resource_pool_az), disk_az_description(volumes))
      else
        uniq_azs.first.nil? || uniq_azs.first.empty? ? nil : uniq_azs.first
      end
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
