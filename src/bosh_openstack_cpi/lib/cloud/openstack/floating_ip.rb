module Bosh::OpenStackCloud
  class FloatingIp
    include Helpers

    def self.reassociate(openstack, ip, server, network_id)
      if openstack.use_nova_networking?
        nova_reassociate(openstack.compute, ip, server)
      else
        floating_ip = get_floating_ip(openstack, ip)

        if port_attached?(floating_ip)
          old_port = openstack.network.get_port(floating_ip['port_id']).body['port']
          old_server = openstack.compute.get_server_details(old_port['device_id']).body['server']
          disassociate(openstack, floating_ip, old_server['name'], old_server['id'])
        end

        port_id = get_port_id(openstack, server.id, network_id)
        Bosh::Clouds::Config.logger.info("Associating floating IP '#{ip}' with server '#{server.name} (#{server.id})'")
        openstack.network.associate_floating_ip(floating_ip['id'], port_id)
      end
    end

    private

    def self.port_attached?(floating_ip)
      return false if floating_ip['port_id'].nil? || floating_ip['port_id'].empty?

      true
    end

    def self.disassociate(openstack, floating_ip, server_name, server_id)
      Bosh::Clouds::Config.logger.info("Disassociating floating IP '#{floating_ip['floating_ip_address']}' from server '#{server_name} (#{server_id})'")
      openstack.network.disassociate_floating_ip(floating_ip['id'])
    end

    def self.get_port_id(openstack, server_id, network_id)
      port = openstack.network.ports.all(device_id: server_id, network_id: network_id).first
      cloud_error("Server has no port in network '#{network_id}'") unless port
      port.id
    end

    def self.get_floating_ip(openstack, ip)
      floating_ips = openstack.network.list_floating_ips('floating_ip_address' => ip).body['floatingips']
      if floating_ips.length > 1
        cloud_error("Floating IP '#{ip}' found in multiple networks: #{floating_ips.map { |ip| "'#{ip['floating_network_id']}'" }.join(', ')}")
      elsif floating_ips.empty?
        cloud_error("Floating IP '#{ip}' not allocated")
      end
      floating_ips.first
    end

    def self.nova_reassociate(compute, ip, server)
      address = compute.addresses.find { |a| a.ip == ip }
      if address
        unless address.instance_id.nil?
          Bosh::Clouds::Config.logger.info("Disassociating floating IP '#{ip}' from server '#{address.instance_id}'")
          address.server = nil
        end

        Bosh::Clouds::Config.logger.info("Associating floating IP '#{ip}' with server '#{server.id}'")
        address.server = server
      else
        cloud_error("Floating IP #{ip} not allocated")
      end
    end
  end
end
