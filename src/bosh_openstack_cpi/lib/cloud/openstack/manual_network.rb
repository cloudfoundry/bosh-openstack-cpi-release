module Bosh::OpenStackCloud
  ##
  # Represents OpenStack manual network: where user sets VM's IP
  class ManualNetwork < Network

    attr_reader :nic
    ##
    # Creates a new manual network
    #
    # @param [String] name Network name
    # @param [Hash] spec Raw network spec
    def initialize(name, spec)
      super
      @nic = {
          'net_id' => net_id
      }
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
        port = create_port_for_manual_network(openstack, net_id, @ip, security_group_ids)
        @logger.debug("Port with ID #{port.id} and MAC address #{port.mac_address} created")
        @nic['port_id'] = port.id
        @spec['mac'] = port.mac_address
      end
    end

    def create_port_for_manual_network(openstack, net_id, ip_address, security_group_ids)
      with_openstack {
        openstack.network.ports.create({
            network_id: net_id,
            fixed_ips: [{ip_address: ip_address}],
            security_groups: security_group_ids
        })
      }
    end

    def net_id
      @spec.fetch("cloud_properties", {})
           .fetch("net_id"          , nil)
    end

    def cleanup(openstack)
      unless openstack.use_nova_networking?
        port = openstack.network.ports.get(@nic['port_id'])
        port.destroy if port
      end
    end
  end
end
