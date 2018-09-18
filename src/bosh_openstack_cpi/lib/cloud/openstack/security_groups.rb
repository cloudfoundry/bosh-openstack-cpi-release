module Bosh::OpenStackCloud
  class SecurityGroups
    include Helpers

    def initialize(openstack)
      @openstack = openstack
    end

    def select_and_retrieve(default_security_groups, network_spec_security_groups, resource_pool_spec_security_groups)
      picked_security_groups = pick_security_groups(
        default_security_groups,
        network_spec_security_groups,
        resource_pool_spec_security_groups,
      )

      openstack_security_groups = @openstack.with_openstack {
        retrieve_security_groups
      }
      map_to_security_groups_in_openstack(picked_security_groups, openstack_security_groups)
    end

    private

    def retrieve_security_groups
      if @openstack.use_nova_networking?
        @openstack.compute.security_groups
      else
        @openstack.network.security_groups
      end
    end

    def pick_security_groups(default_security_groups, network_spec_security_groups, resource_pool_spec_security_groups)
      return resource_pool_spec_security_groups unless resource_pool_spec_security_groups.empty?

      return network_spec_security_groups unless network_spec_security_groups.empty?

      default_security_groups
    end

    def map_to_security_groups_in_openstack(picked_security_groups, openstack_security_groups)
      picked_security_groups.map do |configured_sg|
        openstack_security_group = find_openstack_sg_by_name(openstack_security_groups, configured_sg)
        openstack_security_group ||= find_openstack_sg_by_id(openstack_security_groups, configured_sg)
        cloud_error("Security group `#{configured_sg}' not found") unless openstack_security_group
        openstack_security_group
      end
    end

    def find_openstack_sg_by_name(openstack_security_groups, security_group_name)
      @openstack.with_openstack(retryable: true) do
        openstack_security_groups.find { |openstack_sg| openstack_sg.name == security_group_name }
      end
    end

    def find_openstack_sg_by_id(openstack_security_groups, security_group_id)
      @openstack.with_openstack(retryable: true) do
        openstack_security_groups.find { |openstack_sg| openstack_sg.id == security_group_id }
      end
    end
  end
end
