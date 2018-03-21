module Bosh::OpenStackCloud
  class ResourcePool
    def self.security_groups(resource_pool_spec)
      if resource_pool_spec&.key?('security_groups')
        raise ArgumentError, 'security groups must be an Array' unless resource_pool_spec['security_groups'].is_a?(Array)
        return resource_pool_spec['security_groups']
      end

      []
    end
  end
end
