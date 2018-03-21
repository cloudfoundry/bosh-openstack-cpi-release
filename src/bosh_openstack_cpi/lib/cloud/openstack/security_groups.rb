module Bosh::OpenStackCloud
  class SecurityGroups
    include Helpers

    def self.select_and_retrieve(openstack, default_security_groups, network_spec_security_groups, resource_pool_spec_security_groups)
      picked_security_groups = pick_security_groups(
        default_security_groups,
        network_spec_security_groups,
        resource_pool_spec_security_groups,
      )

      openstack_security_groups = openstack.with_openstack {
        retrieve_security_groups(openstack)
      }

      map_to_security_groups_in_openstack(picked_security_groups, openstack_security_groups)
    end

    private

    def self.retrieve_security_groups(openstack)
      if openstack.use_nova_networking?
        openstack.compute.security_groups
      else
        openstack.network.security_groups
      end
    end

    def self.pick_security_groups(default_security_groups, network_spec_security_groups, resource_pool_spec_security_groups)
      return resource_pool_spec_security_groups unless resource_pool_spec_security_groups.empty?

      return network_spec_security_groups unless network_spec_security_groups.empty?

      default_security_groups
    end

    def self.map_to_security_groups_in_openstack(picked_security_groups, openstack_security_groups)
      picked_security_groups.map do |configured_sg|
        openstack_security_group = openstack_security_groups.find { |openstack_sg| openstack_sg.name == configured_sg }
        cloud_error("Security group `#{configured_sg}' not found") unless openstack_security_group
        openstack_security_group
      end
    end
  end
end
