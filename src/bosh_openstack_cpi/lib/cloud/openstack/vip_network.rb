module Bosh::OpenStackCloud
  ##
  # Represents OpenStack vip network: where users sets VM's IP (floating IP's
  # in OpenStack)
  class VipNetwork < Network

    ##
    # Creates a new vip network
    #
    # @param [String] name Network name
    # @param [Hash] spec Raw network spec
    def initialize(name, spec)
      super
    end

    ##
    # Configures OpenStack vip network
    #
    # @param [Bosh::OpenStackCloud::Openstack] openstack
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server to
    #   configure
    def configure(openstack, server, network_id)
      if @ip.nil?
        cloud_error("No IP provided for vip network `#{@name}'")
      end

      openstack.with_openstack do
        FloatingIp.reassociate(openstack, @ip, server, network_id) unless shared?
      end
    end

    def shared?
      return false unless @cloud_properties
      @cloud_properties.fetch('shared', false)
    end
  end
end
