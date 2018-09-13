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

    def cleanup(openstack)
      unless openstack.use_nova_networking?
        ports = openstack.with_openstack { openstack.network.ports }
        port = openstack.with_openstack(retryable: true) { ports.get(@nic['port_id']) }
        openstack.with_openstack(retryable: true, ignore_not_found: true) { port&.destroy }
      end
    end

    private

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
      openstack.with_openstack do
        retried = false
        begin
          openstack.network.ports.create(port_properties)
        rescue Excon::Error::Conflict => e
          raise e if retried
          delete_conflicting_unused_ports(openstack, net_id)
          @logger.info("Retrying to create port for IP #{@ip} in network #{net_id}")
          retried = true
          retry
        end
      end
    end

    def delete_conflicting_unused_ports(openstack, net_id)
      ports = openstack.network.ports.all("fixed_ips": ["ip_address=#{@ip}", "network_id": net_id])
      detached_port_ids = ports.select { |p| p.status == 'DOWN' && p.device_id.empty? && p.device_owner.empty? }.map(&:id)
      @logger.warn("IP #{@ip} already allocated: Deleting conflicting unused ports with ids=#{detached_port_ids}")
      NetworkConfigurator.cleanup_ports(openstack, detached_port_ids)
    end

    def vrrp_port?(openstack)
      vrrp_port = openstack.with_openstack(retryable: true) {
        openstack.network.ports.all(fixed_ips: "ip_address=#{@allowed_address_pairs}")
      }
      !(vrrp_port.nil? || vrrp_port.empty?)
    end
  end
end
