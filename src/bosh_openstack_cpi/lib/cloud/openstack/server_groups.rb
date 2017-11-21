module Bosh::OpenStackCloud
  class ServerGroups
    include Helpers

    def initialize(openstack)
      @openstack = openstack
    end

    def find_or_create(uuid, jobs)
      name = name(uuid, jobs)
      groups = @openstack.compute.server_groups.all
      if found = groups.find { |group| group.name == name }
        found.id
      else
        result = @openstack.compute.server_groups.create(name, 'soft-anti-affinity')
        result.id
      end
    end

    private

    def name(uuid, jobs)
      "#{uuid}-#{jobs}"
    end
  end
end
