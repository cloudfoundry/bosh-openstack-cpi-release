module Bosh::OpenStackCloud
  class ServerGroups
    POLICY = 'soft-anti-affinity'

    def initialize(openstack)
      @openstack = openstack
    end

    def find_or_create(uuid, bosh_group)
      name = name(uuid, bosh_group)
      @openstack.with_openstack do
        begin
          groups = @openstack.compute.server_groups.all
          if found = groups.find { |group| group.name == name && group.policies.include?(POLICY) }
            found.id
          else
            result = @openstack.compute.server_groups.create(name, POLICY)
            result.id
          end
        rescue Excon::Error::Forbidden => error
          if error.message.include?('Quota exceeded, too many server groups')
            raise Bosh::Clouds::CloudError, "You have reached your quota for server groups for project '#{@openstack.params[:openstack_tenant]}'. Please disable auto-anti-affinity server groups or increase your quota."
          end
          raise error
        rescue Excon::Error::BadRequest => error
          if error.message.match(/Invalid input.*'soft-anti-affinity' is not one of/)
            raise Bosh::Clouds::CloudError, "Your OpenStack does not support the 'soft-anti-affinity' server group policy. Either upgrade your OpenStack to Mitaka or higher, or disable the feature in global CPI config via 'enable_auto_anti_affinity=false'."
          end
          raise error
        end
      end
    end

    private

    def name(uuid, bosh_group)
      "#{uuid}-#{bosh_group}"
    end
  end
end
