# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require 'spec_helper'

describe Bosh::OpenStackCloud::NetworkConfigurator do

  def set_security_groups(spec, security_groups)
    spec['cloud_properties'] ||= {}
    spec['cloud_properties']['security_groups'] = security_groups
  end

  def set_nics(spec, net_id)
    spec['cloud_properties'] ||= {}
  end

  let(:several_manual_networks) do
    {
        'network_a' => manual_network_spec(ip: '10.0.0.1'),
        'network_b' => manual_network_spec(net_id: 'bar', ip: '10.0.0.2')
    }
  end

  it 'exposes network_spec as attribute' do
    spec = {
        'network_a' => {'type' => 'dynamic'}
    }

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
        expect(nc.security_groups).to eq(%w[bar foo] )
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

  describe '#private_ips' do
    context 'when manual network' do
      it 'should extract private ip address' do
        spec = {}
        spec['network_a'] = manual_network_spec
        spec['network_a']['ip'] = '10.0.0.1'

        nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
        expect(nc.private_ips).to eq(%w[10.0.0.1])
      end

      context 'when multiple manual networks' do
        it 'should extract private ip addresses from all' do
          nc = Bosh::OpenStackCloud::NetworkConfigurator.new(several_manual_networks)
          expect(nc.private_ips).to eq(%w[10.0.0.1 10.0.0.2])
        end
      end

      context 'when additional vip network' do
        it 'should extract private ip address from manual network' do
          spec = {}
          spec['network_a'] = vip_network_spec
          spec['network_a']['ip'] = '10.0.0.1'
          spec['network_b'] = manual_network_spec
          spec['network_b']['ip'] = '10.0.0.2'

          nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
          expect(nc.private_ips).to eq(%w[10.0.0.2])
        end
      end
    end

    context 'when dynamic network' do
      it 'should not extract private ip address' do
        spec = {}
        spec['network_a'] = dynamic_network_spec
        spec['network_a']['ip'] = '10.0.0.1'

        nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
        expect(nc.private_ips).to be_empty
      end
    end
  end

  describe '#manual_port_creation?' do
    context 'when no config_drive' do
      context 'and single manual network' do
        it 'should return false' do
          nc = Bosh::OpenStackCloud::NetworkConfigurator.new({'network' => manual_network_spec()})

          expect(nc.manual_port_creation? false).to be false
        end
      end

      context 'when multiple networks' do
        it 'should return false' do
          nc = Bosh::OpenStackCloud::NetworkConfigurator.new(several_manual_networks)

          expect(nc.manual_port_creation? false).to be false
        end
      end
    end

    context 'when config_drive' do
      context 'and single manual network' do
        it 'should return false' do
          nc = Bosh::OpenStackCloud::NetworkConfigurator.new({'network' => manual_network_spec()})

          expect(nc.manual_port_creation? true).to be false
        end
      end

      context 'when multiple networks' do
        it 'should return true' do
          nc = Bosh::OpenStackCloud::NetworkConfigurator.new(several_manual_networks)

          expect(nc.manual_port_creation? true).to be true
        end
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
        expect(nc.nics).to eq([{'net_id' => 'foo'}])
      end

      it 'should not extract ip address' do
        spec = {}
        spec['network_a'] = dynamic_network_spec
        spec['network_a']['ip'] = '10.0.0.1'
        spec['network_a']['cloud_properties']['net_id'] = 'foo'

        nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
        expect(nc.nics).to eq([{'net_id' => 'foo'}])
      end
    end

    context 'when manual network' do

      let(:nc) do
        manual_network = { 'network_a' => manual_network_spec(ip: '10.0.0.1') }
        Bosh::OpenStackCloud::NetworkConfigurator.new(manual_network)
      end

      context 'and no port id is available in network spec' do
        it 'should set fixed ip only' do
          expect(nc.nics).to eq([{'net_id' => 'net', 'v4_fixed_ip' => '10.0.0.1'}])
        end
      end

      context 'and port id is available in network spec' do
        it 'should set port id only' do
          port = double('port', id: '117717c1-81cb-4ac4-96ab-99aaf1be9ca8', mac_address: 'AA:BB:CC:DD:EE:FF')
          expect(nc).to receive(:create_port_for_manual_network).and_return(port)
          nc.prepare_ports_for_manual_networks(nil, nil)

          expect(nc.nics).to eq([{'net_id' => 'net', 'port_id' => '117717c1-81cb-4ac4-96ab-99aaf1be9ca8'}])
        end
      end

      context 'when multiple networks' do
        it 'should extract net_id and IP address from all' do
          nc = Bosh::OpenStackCloud::NetworkConfigurator.new(several_manual_networks)
          expect(nc.nics).to eq([
                                    {'net_id' => 'net', 'v4_fixed_ip' => '10.0.0.1'},
                                    {'net_id' => 'bar', 'v4_fixed_ip' => '10.0.0.2'},
                                ])
        end
      end
    end
  end

  describe '#prepare_ports_for_manual_networks' do
    let(:security_groups_to_be_used) { ['default-security-group-id'] }

    context 'with multiple manual networks' do
      before(:each) do
        port_result_net = double('ports1', id: '117717c1-81cb-4ac4-96ab-99aaf1be9ca8', network_id: 'net', mac_address: 'AA:AA:AA:AA:AA:AA')
        port_result_bar = double('ports2', id: '217715c1-81cb-4ac4-96eb-99aaf1be9ca8', network_id: 'bar', mac_address: 'BB:BB:BB:BB:BB:BB')
        allow(openstack).to receive(:network).and_return(neutron)
        allow(ports).to receive(:create).with(network_id: 'net', fixed_ips: [{ip_address: '10.0.0.1'}], security_groups: ['default-security-group-id']).and_return(port_result_net)
        allow(ports).to receive(:create).with(network_id: 'bar', fixed_ips: [{ip_address: '10.0.0.2'}], security_groups: ['default-security-group-id']).and_return(port_result_bar)
        allow(neutron).to receive(:ports).and_return(ports)
      end

      let(:nc) { Bosh::OpenStackCloud::NetworkConfigurator.new(several_manual_networks) }
      let(:neutron) { double(Fog::Network) }
      let(:openstack) { instance_double(Bosh::OpenStackCloud::Openstack) }
      let(:ports) { double('Fog::Network::OpenStack::Ports') }

      it 'adds port_ids to nics' do
        nc.prepare_ports_for_manual_networks(openstack, security_groups_to_be_used)

        expect(nc.nics).to eq([
                                  {'net_id' => 'net', 'port_id' => '117717c1-81cb-4ac4-96ab-99aaf1be9ca8'},
                                  {'net_id' => 'bar', 'port_id' => '217715c1-81cb-4ac4-96eb-99aaf1be9ca8'}
                              ])
      end

      it 'adds MAC addresses to network spec' do
        nc.prepare_ports_for_manual_networks(openstack, security_groups_to_be_used)
        
        expect(nc.network_spec['network_a']['mac']).to eq('AA:AA:AA:AA:AA:AA')
        expect(nc.network_spec['network_b']['mac']).to eq('BB:BB:BB:BB:BB:BB')
      end

      it 'sets the given security groups for the port' do
        nc.prepare_ports_for_manual_networks(openstack, security_groups_to_be_used)

        expect(ports).to have_received(:create).with(network_id: anything, fixed_ips: anything, security_groups: ['default-security-group-id']).twice
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
          'network_b' => manual_network_spec,
          'network_c' => vip_network_spec
        }
      end

      it 'configures the vip network and all other networks too' do
        expect(vip_network).to receive(:configure)
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
    let(:openstack) { instance_double(Bosh::OpenStackCloud::Openstack) }

    context 'when neutron is available' do

      it 'should return all device ports' do
        port = double('port', :id => 'port_id')
        ports = double('ports', :all => [])
        allow(openstack).to receive(:network).and_return(neutron)
        allow(neutron).to receive(:ports).and_return(ports)
        allow(ports).to receive(:all).with(:device_id => 'server_id').and_return([port])

        expect(Bosh::OpenStackCloud::NetworkConfigurator.port_ids(openstack, 'server_id')).to eq(['port_id'])
      end
    end

    context 'when neutron returns error or is not available' do
      it 'should return no ports' do
        allow(openstack).to receive(:network).and_raise(Bosh::Clouds::CloudError)

        expect(Bosh::OpenStackCloud::NetworkConfigurator.port_ids(openstack, 'server_id')).to eq([])
      end
    end
  end

  describe '.cleanup_ports' do
    let(:neutron) { double(Fog::Network) }
    let(:openstack) { instance_double(Bosh::OpenStackCloud::Openstack) }
    let(:port_a) { double('port_a', :id => 'port_a_id') }
    let(:port_b) { double('port_b', :id => 'port_b_id') }

    context 'when neutron is available' do
      it 'should delete all ports' do
        ports = double('ports')
        allow(openstack).to receive(:network).and_return(neutron).exactly(2).times
        allow(neutron).to receive(:ports).and_return(ports).exactly(2).times
        allow(ports).to receive(:get).with('port_a_id').and_return(port_a)
        allow(ports).to receive(:get).with('port_b_id').and_return(port_b)
        allow(port_a).to receive(:destroy)
        allow(port_b).to receive(:destroy)

        expect(Bosh::OpenStackCloud::NetworkConfigurator.cleanup_ports(openstack, ['port_a_id', 'port_b_id']))
      end

      it 'should not fail on already deleted ports' do
        ports = double('ports')
        allow(openstack).to receive(:network).and_return(neutron).exactly(2).times
        allow(neutron).to receive(:ports).and_return(ports).exactly(2).times
        allow(ports).to receive(:get).with('port_a_id').and_return(nil)
        allow(ports).to receive(:get).with('port_b_id').and_return(nil)

        expect{
          Bosh::OpenStackCloud::NetworkConfigurator.cleanup_ports(openstack, ['port_a_id', 'port_b_id'])
        }.to_not raise_error
      end
    end

    context 'when neutron is not available' do
      it 'should not raise any error' do
        allow(openstack).to receive(:network).and_return(neutron).and_raise(Bosh::Clouds::CloudError)

        expect{
          Bosh::OpenStackCloud::NetworkConfigurator.cleanup_ports(openstack, [port_a, port_b])
        }.to_not raise_error
      end
    end

  end

end
