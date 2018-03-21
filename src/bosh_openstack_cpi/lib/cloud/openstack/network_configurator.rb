module Bosh::OpenStackCloud
  ##
  # Represents OpenStack server network config. OpenStack server has single NIC
  # with a dynamic or manual IP's address and (optionally) a single floating
  # IP address which server itself is not aware of (vip). Thus we should
  # perform a number of sanity checks for the network spec provided by director
  # to make sure we don't apply something OpenStack doesn't understand how to
  # deal with.
  class NetworkConfigurator
    include Helpers

    attr_reader :network_spec, :networks

    ##
    # Creates new network spec
    #
    # @param [Hash] spec Raw network spec passed by director
    def initialize(spec, allowed_address_pairs = nil)
      raise ArgumentError, "Invalid spec, Hash expected, #{spec.class} provided" unless spec.is_a?(Hash)

      @network_spec = spec
      @logger = Bosh::Clouds::Config.logger
      @networks = []
      @vip_network = nil
      @security_groups = []
      @net_ids = []
      @dynamic_network = nil

      spec.each_pair do |name, network_spec|
        initialize_network(name, network_spec)
      end

      cloud_error('At least one dynamic or manual network should be defined') if @networks.empty?
      add_vrrp_ip_to_default_network(allowed_address_pairs) if allowed_address_pairs
    end

    def check_preconditions(use_nova_networking, config_drive, use_dhcp)
      return unless multiple_private_networks?

      if use_nova_networking
        error_message = "Multiple manual networks can only be used with 'openstack.use_nova_networking=false'. Multiple networks require Neutron."
        raise Bosh::Clouds::VMCreationFailed.new(false), error_message
      end

      if use_dhcp || !config_drive
        error_message = "Multiple manual networks can only be used with 'openstack.use_dhcp=false' and 'openstack.config_drive=cdrom|disk'"
        raise Bosh::Clouds::VMCreationFailed.new(false), error_message
      end
    end

    def prepare(openstack, security_group_ids)
      @networks.each do |network|
        network.prepare(openstack, security_group_ids)
      end
    end

    def cleanup(openstack)
      @networks.each do |network|
        network.cleanup(openstack)
      end
    end

    ##
    # Setup network configuration for one network spec.
    #
    # @param [String] network spec name
    # @param [Hash] network spec
    #   configure
    def initialize_network(name, network_spec)
      network_type = NetworkConfigurator.network_type(network_spec)

      case network_type
      when 'dynamic'
        cloud_error('Only one dynamic network per instance should be defined') if @dynamic_network
        net_id = NetworkConfigurator.extract_net_id(network_spec)
        cloud_error("Dynamic network with id #{net_id} is already defined") if @net_ids.include?(net_id)
        network = DynamicNetwork.new(name, network_spec)
        @security_groups += extract_security_groups(network_spec)
        @networks << network
        @net_ids << net_id
        @dynamic_network = network
      when 'manual'
        net_id = NetworkConfigurator.extract_net_id(network_spec)
        cloud_error('Manual network must have net_id') if net_id.nil?
        cloud_error("Manual network with id #{net_id} is already defined") if @net_ids.include?(net_id)
        network = ManualNetwork.new(name, network_spec)
        @security_groups += extract_security_groups(network_spec)
        @networks << network
        @net_ids << net_id
      when 'vip'
        cloud_error('Only one VIP network per instance should be defined') if @vip_network
        @vip_network = VipNetwork.new(name, network_spec)
        @security_groups += extract_security_groups(network_spec)
      else
        cloud_error("Invalid network type `#{network_type}': OpenStack " \
                    "CPI can only handle `dynamic', 'manual' or `vip' " \
                    'network types')
      end

      @security_groups.uniq!
    end

    def self.get_gateway_network(network_spec)
      private_network_specs = private_network_specs(network_spec)
      spec = if private_network_specs.size == 1
               private_network_specs.first
             else
               private_network_specs.select do |spec|
                 spec['defaults']&.include?('gateway')
               end.first
      end
      spec
    end

    def self.get_gateway_network_id(network_spec)
      network = get_gateway_network(network_spec)
      extract_net_id(network)
    end

    def self.matching_gateway_subnet_ids_for_ip(network_spec, openstack, ip)
      network_id = get_gateway_network_id(network_spec)
      network_subnets = openstack.network.list_subnets('network_id' => network_id).body['subnets']
      network_subnets.select do |subnet|
        NetAddr::CIDR.create(subnet['cidr']).matches?(ip)
      end.map { |subnet| subnet['id'] }
    end

    def self.gateway_ip(network_spec, openstack, server)
      network = get_gateway_network(network_spec)
      network_type = network_type(network)

      if network_type == 'manual'
        network['ip']
      elsif network_type == 'dynamic'
        if private_network_specs(network_spec).size > 1
          raise Bosh::Clouds::VMCreationFailed.new(false), 'Gateway IP address could not be determined. Gateway network is dynamic, but additional private networks exist.'
        end

        openstack.with_openstack {
          return server.addresses.values.first.dig(0, 'addr')
        }
      end
    end

    ##
    # Applies network configuration to the vm
    #
    # @param [Bosh::OpenStackCloud::Openstack] openstack
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server to
    #   configure
    def configure(openstack, server)
      @networks.each do |network|
        network.configure(openstack, server)
      end

      @vip_network&.configure(openstack, server, NetworkConfigurator.get_gateway_network_id(@network_spec))
    end

    ##
    # Returns the sorted security groups for this network configuration
    #
    # @return [Array] security groups
    def security_groups
      @security_groups.sort
    end

    ##
    # Returns the nics for this network configuration
    #
    # @return [Array] nics
    def nics
      @networks.each_with_object([]) do |network, memo|
        nic = network.nic
        memo << nic if nic.any?
      end
    end

    def self.port_ids(openstack, server_id)
      return [] if openstack.use_nova_networking?
      ports = openstack.with_openstack {
        openstack.network.ports.all(device_id: server_id)
      }
      ports.map(&:id)
    end

    def self.cleanup_ports(openstack, port_ids)
      return if openstack.use_nova_networking?
      port_ids.each do |port_id|
        openstack.with_openstack {
          port = openstack.network.ports.get(port_id)
          if port
            Bosh::Clouds::Config.logger.debug("Deleting port #{port_id}")
            port.destroy
          end
        }
      end
    end

    private

    def add_vrrp_ip_to_default_network(allowed_address_pairs)
      @networks.each do |network|
        network.allowed_address_pairs = allowed_address_pairs if default_network?(network)
      end
    end

    def default_network?(network)
      default_network_spec = NetworkConfigurator.get_gateway_network(@network_spec)
      network.spec == default_network_spec
    end

    def self.network_type(network)
      # in case of a manual network bosh doesn't provide a type.
      network.fetch('type', 'manual')
    end

    def self.private_network_specs(network_spec)
      network_spec.values.reject { |spec| spec['type'] == 'vip' }
    end

    def multiple_private_networks?
      @networks.length > 1
    end

    ##
    # Extracts the security groups from the network configuration
    #
    # @param [Hash] network_spec Network specification
    # @return [Array] security groups
    # @raise [ArgumentError] if the security groups in the network_spec is not an Array
    def extract_security_groups(network_spec)
      if network_spec && network_spec['cloud_properties']
        cloud_properties = network_spec['cloud_properties']
        if cloud_properties&.key?('security_groups')
          raise ArgumentError, 'security groups must be an Array' unless cloud_properties['security_groups'].is_a?(Array)
          return cloud_properties['security_groups']
        end
      end
      []
    end

    ##
    # Extracts the network ID from the network configuration
    #
    # @param [Hash] network_spec Network specification
    # @return [Hash] network ID
    def self.extract_net_id(network_spec)
      if network_spec && network_spec['cloud_properties']
        cloud_properties = network_spec['cloud_properties']
        return cloud_properties['net_id'] if cloud_properties&.key?('net_id')
      end
      nil
    end
  end
end
