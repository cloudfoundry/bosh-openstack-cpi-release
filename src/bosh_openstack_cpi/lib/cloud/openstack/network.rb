module Bosh::OpenStackCloud
  ##
  # Represents OpenStack network.
  class Network
    include Helpers

    attr_reader :name, :spec

    ##
    # Creates a new network
    #
    # @param [String] name Network name
    # @param [Hash] spec Raw network spec
    def initialize(name, spec)
      unless spec.is_a?(Hash)
        raise ArgumentError, "Invalid spec, Hash expected, #{spec.class} provided"
      end

      @logger = Bosh::Clouds::Config.logger
      @spec = spec
      @name = name
      @ip = spec['ip']
      @cloud_properties = spec['cloud_properties']
    end

    ##
    # Configures given server
    #
    # @param [Bosh::OpenStackCloud::Openstack] openstack
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server to configure
    def configure(openstack, server)
    end

    def prepare(openstack, security_groups, allowed_address_pairs)
    end

    def cleanup(openstack)
    end

  end
end
