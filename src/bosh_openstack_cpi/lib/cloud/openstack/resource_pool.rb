module Bosh::OpenStackCloud
  class ResourcePool

    def self.security_groups(resource_pool_spec)

      if resource_pool_spec && resource_pool_spec.has_key?('security_groups')
        unless resource_pool_spec['security_groups'].is_a?(Array)
          raise ArgumentError, 'security groups must be an Array'
        end
        return resource_pool_spec['security_groups']
      end

      []
    end

  end
end
