module Bosh::OpenStackCloud
  ##
  # Represents OpenStack manual network: where user sets VM's IP
  class ManualNetwork < PrivateNetwork
    ##
    # Creates a new manual network
    #
    # @param [String] name Network name
    # @param [Hash] spec Raw network spec
    def initialize(name, spec)
      super
    end

    ##
    # Returns the private IP address
    #
    # @return [String] ip address
    def private_ip
      @ip
    end

    def prepare(openstack, security_group_ids)
      if openstack.use_nova_networking?
        @nic['v4_fixed_ip'] = @ip
      else
        @logger.debug("Creating port for IP #{@ip} in network #{net_id}")
        port = create_port_for_manual_network(openstack, net_id, security_group_ids)
        @logger.debug("Port with ID #{port.id} and MAC address #{port.mac_address} created")
        @nic['port_id'] = port.id
        @spec['mac'] = port.mac_address
      end
    end

    def create_port_for_manual_network(openstack, net_id, security_group_ids)
      port_properties = {
        network_id: net_id,
        fixed_ips: [{ ip_address: @ip }],
        security_groups: security_group_ids,
      }
      if @allowed_address_pairs
        cloud_error("Configured VRRP port with ip '#{@allowed_address_pairs}' does not exist.") unless vrrp_port?(openstack)
        port_properties[:allowed_address_pairs] = [{ ip_address: @allowed_address_pairs }]
      end
      openstack.with_openstack { openstack.network.ports.create(port_properties) }
    end

    def cleanup(openstack)
      unless openstack.use_nova_networking?
        port = openstack.network.ports.get(@nic['port_id'])
        port&.destroy
      end
    end

    private

    def vrrp_port?(openstack)
      vrrp_port = openstack.with_openstack { openstack.network.ports.all(fixed_ips: "ip_address=#{@allowed_address_pairs}") }
      !(vrrp_port.nil? || vrrp_port.empty?)
    end
  end
end
