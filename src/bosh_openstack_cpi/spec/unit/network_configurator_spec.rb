require 'spec_helper'
require 'fog/openstack/compute/models/server'

describe Bosh::OpenStackCloud::NetworkConfigurator do
  def set_security_groups(spec, security_groups)
    spec['cloud_properties'] ||= {}
    spec['cloud_properties']['security_groups'] = security_groups
  end

  def set_nics(spec, _net_id)
    spec['cloud_properties'] ||= {}
  end

  let(:several_manual_networks) do
    {
      'network_a' => manual_network_spec(ip: '10.0.0.1'),
      'network_b' => manual_network_spec(net_id: 'bar', ip: '10.0.0.2'),
    }
  end
  let(:openstack) { instance_double(Bosh::OpenStackCloud::Openstack) }
  let(:spec) {
    {
      'network_a' => { 'type' => 'dynamic' },
    }
  }


  before { allow(openstack).to receive(:with_openstack) { |&block| block.call } }

  it 'exposes network_spec as attribute' do
    nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
    expect(nc.network_spec).to eq(spec)
  end

  describe '#initialize' do
    context 'when spec is not a hash' do
      it 'should raise an error' do
        expect {
          Bosh::OpenStackCloud::NetworkConfigurator.new('foo')
        }.to raise_error ArgumentError, /Invalid spec, Hash expected,/
      end
    end

    context 'when no net_id defined in manual networks' do
      it 'should raise a CloudError' do
        spec = {}
        spec['network_b'] = manual_network_without_netid_spec

        expect {
          Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
        }.to raise_error Bosh::Clouds::CloudError, 'Manual network must have net_id'
      end
    end

    context 'when several manual networks have the same net_id' do
      it 'should raise a CloudError' do
        spec = several_manual_networks
        spec['network_b']['cloud_properties']['net_id'] = 'net'

        expect {
          Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
        }.to raise_error Bosh::Clouds::CloudError, 'Manual network with id net is already defined'
      end
    end

    context 'when several dynamic networks are defined' do
      it 'should raise a CloudError' do
        spec = {}
        spec['network_a'] = dynamic_network_spec
        spec['network_b'] = dynamic_network_spec

        expect {
          Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
        }.to raise_error Bosh::Clouds::CloudError, 'Only one dynamic network per instance should be defined'
      end
    end

    context 'when several VIP networks are defined' do
      it 'should raise a CloudError' do
        spec = {}
        spec['network_a'] = vip_network_spec
        spec['network_b'] = vip_network_spec

        expect {
          Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
        }.to raise_error Bosh::Clouds::CloudError, 'Only one VIP network per instance should be defined'
      end
    end

    context 'when only VIP network is defined' do
      it 'should raise a CloudError' do
        spec = {}
        spec['network_a'] = vip_network_spec

        expect {
          Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
        }.to raise_error Bosh::Clouds::CloudError, 'At least one dynamic or manual network should be defined'
      end
    end

    context 'when vrrp' do
      context 'is configured' do
        it 'should set allowed_address_pair to the default network' do
          vrrp_port = '10.0.0.10'
          network_configurator = Bosh::OpenStackCloud::NetworkConfigurator.new({
            'network_a' => manual_network_spec(ip: '10.0.0.1'),
            'network_b' => manual_network_spec(net_id: 'bar', ip: '10.0.0.2', defaults: ['gateway']),
            'network_c' => dynamic_network_spec,
          }, vrrp_port)

          network_configurator.networks.each do |network|
            if network.name == 'network_b'
              expect(network.allowed_address_pairs).to eq(vrrp_port)
            else
              expect(network.allowed_address_pairs).to eq(nil)
            end
          end
        end
      end

      context 'is not configured' do
        it 'should set allowed_address_pair to the default network' do
          network_configurator = Bosh::OpenStackCloud::NetworkConfigurator.new(
            'network_a' => manual_network_spec(ip: '10.0.0.1'),
            'network_b' => manual_network_spec(net_id: 'bar', ip: '10.0.0.2', defaults: ['gateway']),
            'network_c' => dynamic_network_spec,
          )

          network_configurator.networks.each do |network|
            expect(network.allowed_address_pairs).to eq(nil)
          end
        end
      end
    end
  end

  describe '#security_groups' do
    context 'when security_groups are defined in all networks' do
      it 'extracts all unique ones from all networks' do
        spec = {}
        spec['network_a'] = dynamic_network_spec
        set_security_groups(spec['network_a'], %w[foo])
        spec['network_b'] = vip_network_spec
        set_security_groups(spec['network_b'], %w[bar])
        spec['network_c'] = manual_network_spec
        set_security_groups(spec['network_c'], %w[foo])

        nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
        expect(nc.security_groups).to eq(%w[bar foo])
      end
    end

    context 'when security_groups is not an array' do
      it 'should raise an ArgumentError' do
        spec = {}
        spec['network_a'] = dynamic_network_spec
        set_security_groups(spec['network_a'], 'foo')

        expect {
          Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
        }.to raise_error ArgumentError, 'security groups must be an Array'
      end
    end
  end

  describe '#nics' do
    context 'when dynamic network' do
      it 'should extract net_id' do
        spec = {}
        spec['network_a'] = dynamic_network_spec
        spec['network_a']['cloud_properties']['net_id'] = 'foo'

        nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
        expect(nc.nics).to eq([{ 'net_id' => 'foo' }])
      end

      it 'should not extract ip address' do
        spec = {}
        spec['network_a'] = dynamic_network_spec
        spec['network_a']['ip'] = '10.0.0.1'
        spec['network_a']['cloud_properties']['net_id'] = 'foo'

        nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
        expect(nc.nics).to eq([{ 'net_id' => 'foo' }])
      end
    end

    context 'when manual network' do
      let(:nc) do
        manual_network = { 'network_a' => manual_network_spec(ip: '10.0.0.1') }
        Bosh::OpenStackCloud::NetworkConfigurator.new(manual_network)
      end

      context 'and no port id is available in network spec' do
        let(:openstack) { instance_double(Bosh::OpenStackCloud::Openstack, use_nova_networking?: true) }
        it 'should set fixed ip only' do
          nc.prepare(openstack)

          expect(nc.nics).to eq([{ 'net_id' => 'net', 'v4_fixed_ip' => '10.0.0.1' }])
        end
      end

      context 'and port id is available in network spec' do
        let(:openstack) { instance_double(Bosh::OpenStackCloud::Openstack, use_nova_networking?: false) }
        before(:each) do
          allow_any_instance_of(Bosh::OpenStackCloud::ManualNetwork).to receive(:nic).and_return('net_id' => 'net', 'port_id' => '117717c1-81cb-4ac4-96ab-99aaf1be9ca8')
          allow_any_instance_of(Bosh::OpenStackCloud::ManualNetwork).to receive(:prepare)
        end

        it 'should set port id only' do
          nc.prepare(openstack)

          expect(nc.nics).to eq([{ 'net_id' => 'net', 'port_id' => '117717c1-81cb-4ac4-96ab-99aaf1be9ca8' }])
        end
      end

      context 'when multiple networks' do
        let(:openstack) { instance_double(Bosh::OpenStackCloud::Openstack, use_nova_networking?: true) }
        it 'should extract net_id and IP address from all' do
          nc = Bosh::OpenStackCloud::NetworkConfigurator.new(several_manual_networks)
          nc.prepare(openstack)

          expect(nc.nics).to eq([
                                  { 'net_id' => 'net', 'v4_fixed_ip' => '10.0.0.1' },
                                  { 'net_id' => 'bar', 'v4_fixed_ip' => '10.0.0.2' },
                                ])
        end
      end
    end
  end

  describe '#prepare' do
    let(:openstack) { instance_double(Bosh::OpenStackCloud::Openstack, use_nova_networking?: true) }
    let(:networks) { [] }

    before(:each) do
      [Bosh::OpenStackCloud::ManualNetwork, Bosh::OpenStackCloud::DynamicNetwork].each do |class_name|
        allow(class_name).to receive(:new) do |name, spec|
          network = instance_double(class_name, prepare: nil, name: name, spec: spec)
          networks << network
          network
        end
      end
    end

    it 'should delegate to all private networks' do
      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(
        'network_a' => manual_network_spec(ip: '10.0.0.1'),
        'network_b' => manual_network_spec(net_id: 'bar', ip: '10.0.0.2'),
        'network_c' => dynamic_network_spec,
      )

      nc.prepare(openstack)

      networks.each do |network|
        expect(network).to have_received(:prepare).with(anything, anything)
      end
    end
  end

  describe '#pick_groups' do
      let(:default_security_groups) { 'fake-group' }
      let(:resource_pool_groups) { 'fake-group' }
      let(:security_groups) { [double('security_-group', name: 'group')] }

    it 'picks a group and logs  it' do
      allow(Bosh::OpenStackCloud::SecurityGroups).to receive(:select_and_retrieve).and_return(security_groups)
      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
      nc.pick_groups(openstack, default_security_groups, resource_pool_groups)
      expect(Bosh::OpenStackCloud::SecurityGroups).to have_received(:select_and_retrieve).with(openstack, default_security_groups, [], resource_pool_groups)
      expect(Bosh::Clouds::Config.logger).to have_received(:debug).with("Using security groups: `group'")
    end
  end

  describe '#cleanup' do
    let(:openstack) { instance_double(Bosh::OpenStackCloud::Openstack, use_nova_networking?: true) }
    let(:networks) { [] }

    before(:each) do
      [Bosh::OpenStackCloud::ManualNetwork, Bosh::OpenStackCloud::DynamicNetwork].each do |class_name|
        allow(class_name).to receive(:new) do
          network = instance_double(class_name, cleanup: nil)
          networks << network
          network
        end
      end
    end

    it 'should delegate to all private networks' do
      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(
        'network_a' => manual_network_spec(ip: '10.0.0.1'),
        'network_b' => manual_network_spec(net_id: 'bar', ip: '10.0.0.2'),
        'network_c' => dynamic_network_spec,
      )

      nc.cleanup(openstack)

      networks.each do |network|
        expect(network).to have_received(:cleanup)
      end
    end
  end

  describe '#configure' do
    let(:vip_network) do
      network = double('vip_network')
      allow(Bosh::OpenStackCloud::VipNetwork).to receive(:new).and_return(network)
      network
    end
    let(:dynamic_network) do
      network = double('dynamic_network')
      allow(Bosh::OpenStackCloud::DynamicNetwork).to receive(:new).and_return(network)
      network
    end
    let(:manual_network) do
      network = double('manual_network')
      allow(Bosh::OpenStackCloud::ManualNetwork).to receive(:new).and_return(network)
      network
    end

    context 'With vip network' do
      let(:network_spec) do
        {
          'network_a' => dynamic_network_spec,
          'network_b' => manual_network_spec(net_id: 'net_b', defaults: ['gateway']),
          'network_c' => vip_network_spec,
        }
      end

      it 'configures the vip network and all other networks too' do
        expect(vip_network).to receive(:configure).with(anything, anything, 'net_b')
        expect(manual_network).to receive(:configure)
        expect(dynamic_network).to receive(:configure)
        network_configurator = Bosh::OpenStackCloud::NetworkConfigurator.new(network_spec)
        network_configurator.configure(nil, nil)
      end
    end

    context 'when no vip network' do
      let(:network_spec) do
        {
          'network_a' => dynamic_network_spec,
          'network_b' => manual_network_spec,
        }
      end

      context 'when no floating IP is associated' do
        it 'should not configure the vip_network' do
          expect(manual_network).to receive(:configure)
          expect(dynamic_network).to receive(:configure)
          expect(vip_network).to_not receive(:configure)

          network_configurator = Bosh::OpenStackCloud::NetworkConfigurator.new(network_spec)
          network_configurator.configure(nil, nil)
        end
      end
    end
  end

  describe '.port_ids' do
    let(:neutron) { double(Fog::Network) }

    context 'when neutron is available' do
      let(:openstack) { instance_double(Bosh::OpenStackCloud::Openstack, use_nova_networking?: false) }

      it 'should return all device ports' do
        port = double('port', id: 'port_id')
        ports = double('ports', all: [])
        allow(openstack).to receive(:network).and_return(neutron)
        allow(neutron).to receive(:ports).and_return(ports)
        allow(ports).to receive(:all).with(device_id: 'server_id').and_return([port])

        expect(Bosh::OpenStackCloud::NetworkConfigurator.port_ids(openstack, 'server_id')).to eq(['port_id'])
      end
    end

    context 'when neutron returns error or is not available' do
      let(:openstack) { instance_double(Bosh::OpenStackCloud::Openstack, use_nova_networking?: true) }

      it 'should return no ports' do
        allow(openstack).to receive(:network)

        expect(Bosh::OpenStackCloud::NetworkConfigurator.port_ids(openstack, 'server_id')).to eq([])

        expect(openstack).to_not have_received(:network)
      end
    end
  end

  describe '.cleanup_ports' do
    let(:neutron) { double(Fog::Network) }
    let(:port_a) { double('port_a', id: 'port_a_id') }
    let(:port_b) { double('port_b', id: 'port_b_id') }

    context 'when neutron is available' do
      let(:openstack) { instance_double(Bosh::OpenStackCloud::Openstack, use_nova_networking?: false) }
      it 'should delete all ports' do
        ports = double('ports')
        allow(openstack).to receive(:network).and_return(neutron).exactly(2).times
        allow(neutron).to receive(:ports).and_return(ports).exactly(2).times
        allow(ports).to receive(:get).with('port_a_id').and_return(port_a)
        allow(ports).to receive(:get).with('port_b_id').and_return(port_b)
        allow(port_a).to receive(:destroy)
        allow(port_b).to receive(:destroy)

        expect(Bosh::OpenStackCloud::NetworkConfigurator.cleanup_ports(openstack, %w[port_a_id port_b_id]))
      end

      it 'should not fail on already deleted ports' do
        ports = double('ports')
        allow(openstack).to receive(:network).and_return(neutron).exactly(2).times
        allow(neutron).to receive(:ports).and_return(ports).exactly(2).times
        allow(ports).to receive(:get).with('port_a_id').and_return(nil)
        allow(ports).to receive(:get).with('port_b_id').and_return(nil)

        expect {
          Bosh::OpenStackCloud::NetworkConfigurator.cleanup_ports(openstack, %w[port_a_id port_b_id])
        }.to_not raise_error
      end
    end

    context 'when neutron is not available' do
      let(:openstack) { instance_double(Bosh::OpenStackCloud::Openstack, use_nova_networking?: true) }
      it 'should not raise any error' do
        allow(openstack).to receive(:network)

        expect {
          Bosh::OpenStackCloud::NetworkConfigurator.cleanup_ports(openstack, [port_a, port_b])
        }.to_not raise_error

        expect(openstack).to_not have_received(:network)
      end
    end
  end

  describe '.get_gateway_network_id' do
    context 'only one network configured' do
      let(:network_spec) do
        {
          'vip_network' => vip_network_spec,
          'network_a' => manual_network_spec(net_id: 'net_id'),
        }
      end

      it 'should return network id' do
        expect(Bosh::OpenStackCloud::NetworkConfigurator.get_gateway_network_id(network_spec)).to eq('net_id')
      end
    end

    context 'multiple network configured' do
      let(:network_spec) do
        {
          'network_a' =>  manual_network_spec(net_id: 'net_id_a'),
          'network_b' =>  manual_network_spec(net_id: 'net_id_b', defaults: ['gateway']),
          'vip_network' => vip_network_spec,
        }
      end

      it 'should return default gateway network id' do
        expect(Bosh::OpenStackCloud::NetworkConfigurator.get_gateway_network_id(network_spec)).to eq('net_id_b')
      end
    end
  end

  describe '.gateway_ip' do
    let(:server) { instance_double(Fog::OpenStack::Compute::Server) }

    context 'when gateway network is a manual network' do
      let(:network_spec) {
        {
          'network_a' => manual_network_spec(net_id: 'net_id_a', ip: '10.10.10.10', defaults: ['gateway']),
          'vip_network' => vip_network_spec,
        }
      }

      it 'returns the IP address from the gateway network' do
        expect(Bosh::OpenStackCloud::NetworkConfigurator.gateway_ip(network_spec, openstack, server)).to eq('10.10.10.10')
      end

      context 'when other private networks exist' do
        let(:network_spec) {
          {
            'network_a' => manual_network_spec(net_id: 'net_id_a', ip: '10.10.10.10', defaults: ['gateway']),
            'network_b' => manual_network_spec(net_id: 'net_id_b', ip: '20.20.20.20'),
            'network_c' => dynamic_network_with_netid_spec,
            'vip_network' => vip_network_spec,
          }
        }

        it 'returns the IP address from the gateway network' do
          expect(Bosh::OpenStackCloud::NetworkConfigurator.gateway_ip(network_spec, openstack, server)).to eq('10.10.10.10')
        end
      end
    end

    context 'when gateway network is a dynamic network' do
      let(:network_spec) {
        {
          'network_a' => dynamic_network_with_netid_spec.merge('defaults' => ['gateway']),
          'vip_network' => vip_network_spec,
        }
      }

      before(:each) do
        allow(server).to receive(:addresses).and_return('network_a' => [{ 'addr' => '10.20.20.20' }])
      end

      it 'returns the IP address from the gateway network by calling OpenStack' do
        expect(Bosh::OpenStackCloud::NetworkConfigurator.gateway_ip(network_spec, openstack, server)).to eq('10.20.20.20')
        expect(server).to have_received(:addresses)
      end

      context 'when other private networks exist' do
        let(:network_spec) {
          {
            'network_a' => dynamic_network_with_netid_spec.merge('defaults' => ['gateway']),
            'network_b' => manual_network_spec(net_id: 'net_id_b', ip: '10.10.10.10'),
            'vip_network' => vip_network_spec,
          }
        }

        it 'raises an error' do
          expect {
            Bosh::OpenStackCloud::NetworkConfigurator.gateway_ip(network_spec, openstack, server)
          }.to raise_error(Bosh::Clouds::VMCreationFailed, 'Gateway IP address could not be determined. Gateway network is dynamic, but additional private networks exist.')
        end
      end
    end
  end

  describe '.matching_gateway_subnet_ids_for_ip' do
    let(:neutron) { double(Fog::OpenStack::Network) }
    let(:list_subnets_response) { double('list_subnets', body: { 'subnets' => subnets }) }

    before(:each) do
      allow(openstack).to receive(:network).and_return(neutron)
      allow(neutron).to receive(:list_subnets).and_return(list_subnets_response)
    end

    context 'when no sub-networks exist' do
      let(:network_spec) { { 'network_a' => manual_network_spec(net_id: 'net_id_a', ip: '10.10.10.10', defaults: ['gateway']) } }
      let(:subnets) { [] }

      it 'returns an empty list' do
        subnet_ids = Bosh::OpenStackCloud::NetworkConfigurator.matching_gateway_subnet_ids_for_ip(network_spec, openstack, '10.0.0.4')

        expect(subnet_ids.empty?).to be_truthy
      end
    end

    context 'when only one sub-network exists' do
      let(:network_spec) { { 'network_a' => manual_network_spec(net_id: 'net_id_a', ip: '10.10.10.10', defaults: ['gateway']) } }
      let(:subnets) { [{ 'id' => 'subnet_id', 'cidr' => '10.0.0.0/24' }] }

      it 'returns the gateway sub-network id' do
        subnet_ids = Bosh::OpenStackCloud::NetworkConfigurator.matching_gateway_subnet_ids_for_ip(network_spec, openstack, '10.0.0.2')

        expect(subnet_ids).to eq(['subnet_id'])
      end
    end

    context 'when more than one sub-network exist' do
      let(:network_spec) {
        {
          'network_a' => manual_network_spec(net_id: 'net_id_a', ip: '10.10.10.10', defaults: ['gateway']),
        }
      }
      let(:subnets) { [{ 'id' => 'subnet_id', 'cidr' => '10.0.0.0/24' }, { 'id' => 'second_subnet_id', 'cidr' => '20.20.20.0/24' }] }
      it 'returns the sub-network id that matches the ip' do
        subnet_ids = Bosh::OpenStackCloud::NetworkConfigurator.matching_gateway_subnet_ids_for_ip(network_spec, openstack, '20.20.20.2')

        expect(subnet_ids).to eq(['second_subnet_id'])
      end

      context 'when sub-networks are with overlapping ranges' do
        let(:subnets) { [{ 'id' => 'subnet_id', 'cidr' => '10.0.0.0/16' }, { 'id' => 'second_subnet_id', 'cidr' => '10.0.0.0/24' }] }

        it 'returns a list of matching subnets' do
          subnet_ids = Bosh::OpenStackCloud::NetworkConfigurator.matching_gateway_subnet_ids_for_ip(network_spec, openstack, '10.0.0.4')

          expect(subnet_ids).to eq(%w[subnet_id second_subnet_id])
        end
      end
    end
  end

  describe '#check_preconditions' do
    context 'when multiple manual networks' do
      subject do
        network_spec = {
          'network_a' => manual_network_spec(net_id: 'network_a', ip: '10.0.0.1'),
          'network_b' => manual_network_spec(net_id: 'network_b', ip: '10.1.0.1'),
        }
        Bosh::OpenStackCloud::NetworkConfigurator.new(network_spec)
      end

      let(:use_nova_networking) { false }
      let(:use_config_drive) { true }
      let(:use_dhcp) { false }

      it 'does not raise error when preconditions are met' do
        expect {
          subject.check_preconditions(use_nova_networking, use_config_drive, use_dhcp)
        }.to_not raise_error
      end

      context "when 'use_nova_networking' is true" do
        let(:use_nova_networking) { true }

        it 'raises VMCreationFailed' do
          expect {
            subject.check_preconditions(use_nova_networking, use_config_drive, use_dhcp)
          }.to raise_error { |e|
            expect(e).to be_a(Bosh::Clouds::VMCreationFailed)
            expect(e.ok_to_retry).to be(false)
            expect(e.message).to eq("Multiple manual networks can only be used with 'openstack.use_nova_networking=false'. Multiple networks require Neutron.")
          }
        end
      end

      context "when 'use_dhcp' is true" do
        let(:use_dhcp) { true }

        it 'raises VMCreationFailed' do
          expect {
            subject.check_preconditions(use_nova_networking, use_config_drive, use_dhcp)
          }.to raise_error { |e|
            expect(e).to be_a(Bosh::Clouds::VMCreationFailed)
            expect(e.message).to eq("Multiple manual networks can only be used with 'openstack.use_dhcp=false' and 'openstack.config_drive=cdrom|disk'")
          }
        end
      end

      context "when 'config_drive' is not set" do
        let(:use_config_drive) { false }

        it 'raises VMCreationFailed' do
          expect {
            subject.check_preconditions(use_nova_networking, use_config_drive, use_dhcp)
          }.to raise_error { |e|
            expect(e).to be_a(Bosh::Clouds::VMCreationFailed)
            expect(e.message).to eq("Multiple manual networks can only be used with 'openstack.use_dhcp=false' and 'openstack.config_drive=cdrom|disk'")
          }
        end
      end
    end

    context 'when single manual network' do
      subject do
        network_spec = { 'network_a' => manual_network_spec(ip: '10.0.0.1') }
        Bosh::OpenStackCloud::NetworkConfigurator.new(network_spec)
      end
      it 'does not raise' do
        expect {
          subject.check_preconditions(false, false, false)
        }.to_not raise_error
      end
    end
  end
end
