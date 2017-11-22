module Bosh::OpenStackCloud
  class ServerGroups
    POLICY = 'soft-anti-affinity'

    def initialize(openstack)
      @openstack = openstack
    end

    def find_or_create(uuid, bosh_group)
      name = name(uuid, bosh_group)
      groups = @openstack.compute.server_groups.all
      if found = groups.find { |group| group.name == name && group.policies.include?(POLICY) }
        found.id
      else
        result = @openstack.compute.server_groups.create(name, POLICY)
        result.id
      end
    end

    private

    def name(uuid, bosh_group)
      "#{uuid}-#{bosh_group}"
    end
  end
end
