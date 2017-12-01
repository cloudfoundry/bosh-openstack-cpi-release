module Bosh::OpenStackCloud
  class ServerGroups
    include Helpers

    POLICY = 'soft-anti-affinity'

    def initialize(openstack)
      @openstack = openstack
      @logger = Bosh::Clouds::Config.logger
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
            message = "You have reached your quota for server groups for project '#{@openstack.params[:openstack_tenant]}'. Please disable auto-anti-affinity server groups or increase your quota."
            cloud_error(message, error)
          end
          raise error
        rescue Excon::Error::BadRequest => error
          if error.message.match(/Invalid input.*'soft-anti-affinity' is not one of/)
            message = "Auto-anti-affinity is only supported on OpenStack Mitaka or higher. Please upgrade or set 'openstack.enable_auto_anti_affinity=false'."
            cloud_error(message, error)
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
