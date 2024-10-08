module Bosh::OpenStackCloud
  ##
  # Represents OpenStack vip network: where users sets VM's IP (floating IP's
  # in OpenStack)
  class VipNetwork < Network
    ##
    # Configures OpenStack vip network
    #
    # @param [Bosh::OpenStackCloud::Openstack] openstack
    # @param [Fog::OpenStack::Compute::Server] server OpenStack server to
    #   configure
    def configure(openstack, server, network_id)
      cloud_error("No IP provided for vip network `#{@name}'") if @ip.nil?

      openstack.with_openstack do
        FloatingIp.reassociate(openstack, @ip, server, network_id)
      end
    end
  end
end
