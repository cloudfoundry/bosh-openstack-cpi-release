module Bosh::OpenStackCloud
  class ServerGroups
    include Helpers

    POLICY = 'soft-anti-affinity'.freeze

    def initialize(openstack)
      @openstack = openstack
      @logger = Bosh::Clouds::Config.logger
    end

    def find_or_create(uuid, bosh_group)
      name = name(uuid, bosh_group)
      @openstack.with_openstack do
        lock_by_file(bosh_group) do
          begin
            server_group = find(name)
            if server_group
              server_group.id
            else
              result = @openstack.compute.server_groups.create(name, POLICY)
              result.id
            end
          rescue Excon::Error::Forbidden => error
            if error.message.include?('Quota exceeded, too many server groups')
              message = "You have reached your quota for server groups for project '#{@openstack.params[:openstack_tenant]}'. Please disable auto-anti-affinity server groups or increase your quota."
              cloud_error(message, error)
            elsif error.message.include?('Quota exceeded, too many servers in group')
              message = "You have reached your quota for members in a server group for project '#{@openstack.params[:openstack_tenant]}'. Please disable auto-anti-affinity server groups or increase your quota."
              cloud_error(message, error)
            end
            raise error
          rescue Excon::Error::BadRequest => error
            if error.message.match?(/Invalid input.*'soft-anti-affinity' is not one of/)
              message = "Auto-anti-affinity is only supported on OpenStack Mitaka or higher. Please upgrade or set 'openstack.enable_auto_anti_affinity=false'."
              cloud_error(message, error)
            end
            raise error
          end
        end
      end
    end

    def delete_if_no_members(uuid, bosh_group)
      @openstack.with_openstack do
        lock_by_file(bosh_group) do
          server_group = find(name(uuid, bosh_group))
          @openstack.compute.delete_server_group(server_group.id) if server_group&.members&.empty?
        end
      end
    end

    private

    def lock_by_file(bosh_group)
      lock_folder = File.join(Dir.tmpdir, 'openstack-server-groups')
      FileUtils.mkdir_p(lock_folder)
      File.open(File.join(lock_folder, "#{bosh_group}.lock"), 'w') do |f|
        f.flock(File::LOCK_EX)
        yield
      end
    end

    def name(uuid, bosh_group)
      "#{uuid}-#{bosh_group}" # director_uuid-director_name-deployment_name-instance_group_name
    end

    def find(name)
      groups = @openstack.compute.server_groups.all
      groups.find { |group| group.name == name && group.policies.include?(POLICY) }
    end
  end
end
