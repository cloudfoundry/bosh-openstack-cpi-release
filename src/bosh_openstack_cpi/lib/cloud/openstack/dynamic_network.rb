module Bosh::OpenStackCloud
  ##
  # Represents OpenStack dynamic network: where IaaS sets VM's IP
  class DynamicNetwork < Network

    ##
    # Creates a new dynamic network
    #
    # @param [String] name Network name
    # @param [Hash] spec Raw network spec
    def initialize(name, spec)
      super
    end

    ##
    # Configures OpenStack dynamic network. Right now it's a no-op,
    # as dynamic networks are completely managed by OpenStack
    #
    # @param [Bosh::OpenStackCloud::Openstack] openstack
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server to
    #   configure
    def configure(openstack, server)
    end

  end
end
