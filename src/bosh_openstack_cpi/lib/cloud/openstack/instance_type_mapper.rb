module Bosh::OpenStackCloud
  class InstanceTypeMapper
    OS_OVERHEAD_IN_GB = 3
    NO_DISK = 0

    def map(requirements:, flavors:, boot_from_volume: false)
      normalized_requirements = convert_disk_to_GB(requirements)

      possible_flavors = find_possible_flavors(normalized_requirements, flavors, boot_from_volume)
      if possible_flavors.empty?
        raise ["Unable to meet requested VM requirements: #{requirements['cpu']} CPU, #{requirements['ram']} MB RAM, #{requirements['ephemeral_disk_size'] / 1024.0} GB Disk.\n",
               "Available flavors:\n",
               flavors.map { |flavor| "#{flavor.name}: #{flavor.vcpus} CPU, #{flavor.ram} MB RAM, #{flavor.disk} GB Disk\n" }].join
      end

      closest_match = possible_flavors.min_by do |flavor|
        [flavor.vcpus, flavor.ram, flavor.disk + flavor.ephemeral, flavor.disk]
      end

      vm_cloud_properties(normalized_requirements, closest_match, boot_from_volume)
    end

    private

    def find_possible_flavors(requirements, flavors, boot_from_volume)
      valid_flavors = flavors.select do |flavor|
        flavor.vcpus >= requirements['cpu'] &&
          flavor.ram >= requirements['ram'] &&
          flavor.disabled != true
      end

      if boot_from_volume
        boot_from_volume_flavors(valid_flavors)
      else
        boot_default_flavors(requirements, valid_flavors)
      end
    end

    def boot_from_volume_flavors(valid_flavors)
      valid_flavors.select { |flavor| flavor.ephemeral == NO_DISK }
    end

    def boot_default_flavors(requirements, valid_flavors)
      flavors_meeting_ephemeral_requirement = valid_flavors.select do |flavor|
        flavor.ephemeral >= requirements['ephemeral_disk_size'].ceil &&
          flavor.disk >= OS_OVERHEAD_IN_GB
      end
      return flavors_meeting_ephemeral_requirement unless flavors_meeting_ephemeral_requirement.empty?

      flavors_meeting_root_requirement = valid_flavors.select do |flavor|
        flavor.ephemeral == NO_DISK &&
          flavor.disk >= requirements['ephemeral_disk_size'].ceil + OS_OVERHEAD_IN_GB
      end

      flavors_meeting_root_requirement
    end

    def convert_disk_to_GB(requirements)
      normalized = requirements.clone
      normalized['ephemeral_disk_size'] = requirements['ephemeral_disk_size'] / 1024.0
      normalized
    end

    def vm_cloud_properties(requirements, closest_match, boot_from_volume)
      properties = {
        'instance_type' => closest_match.name,
      }

      if boot_from_volume && root_disk_size(closest_match) < required_boot_volume_size(requirements)
        properties.merge(
          'root_disk' => {
            'size' => required_boot_volume_size(requirements),
          },
        )
      else
        properties
      end
    end

    def required_boot_volume_size(requirements)
      OS_OVERHEAD_IN_GB + requirements['ephemeral_disk_size']
    end

    def root_disk_size(flavor)
      flavor.disk
    end
  end
end
