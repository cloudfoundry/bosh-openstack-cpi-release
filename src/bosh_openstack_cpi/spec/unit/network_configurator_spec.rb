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
    spec = {}
    spec['network_a'] = manual_network_spec
    spec['network_a']['ip'] = '10.0.0.1'
    spec['network_b'] = manual_network_spec
    spec['network_b']['cloud_properties']['net_id'] = 'bar'
    spec['network_b']['ip'] = '10.0.0.2'
    spec
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
      it 'should be extracted from all networks' do
        spec = {}
        spec['network_a'] = dynamic_network_spec
        set_security_groups(spec['network_a'], %w[foo])
        spec['network_b'] = vip_network_spec
        set_security_groups(spec['network_b'], %w[bar])
        spec['network_c'] = manual_network_spec
        set_security_groups(spec['network_c'], %w[bla])

        nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
        expect(nc.security_groups).to eq(%w[bar bla foo] )
      end
    end

    context 'when no security_groups are defined' do
      it 'should return the default groups' do
        spec = {}
        spec['network_a'] = {'type' => 'dynamic'}

        nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
        expect(nc.security_groups(%w[foo])).to eq(%w[foo])
      end

      context 'when no default security_group is set' do
        it 'should return an empty list' do
          spec = {}
          spec['network_a'] = {'type' => 'dynamic'}

          nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
          expect(nc.security_groups).to eq([])
        end
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
      it 'should extract net_id and IP address from all' do
        nc = Bosh::OpenStackCloud::NetworkConfigurator.new(several_manual_networks)
        expect(nc.nics).to eq([
                                  {'net_id' => 'net', 'v4_fixed_ip' => '10.0.0.1'},
                                  {'net_id' => 'bar', 'v4_fixed_ip' => '10.0.0.2'},
                              ])
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

      context 'when floating IP associated to the server' do
        it 'disassociate allocated floating IP' do
          server = double('server', :id => 'i-test')
          address = double('address', :id => 'a-test', :ip => '10.0.0.1',
                           :instance_id => 'i-test')

          expect(manual_network).to receive(:configure)
          expect(dynamic_network).to receive(:configure)
          expect(vip_network).to_not receive(:configure)
          cloud = mock_cloud do |openstack|
            expect(openstack).to receive(:addresses).and_return([address])
          end
          expect(address).to receive(:server=).with(nil)

          network_configurator = Bosh::OpenStackCloud::NetworkConfigurator.new(network_spec)
          network_configurator.configure(cloud.compute, server)
        end
      end

      context 'when no floating IP associated to the server but to others' do
        it 'should not disassociate any floating IP' do
          other_server = double('server', :id => 'i-test2')
          address = double('address', :id => 'a-test', :ip => '10.0.0.1',
                           :instance_id => 'i-test')

          expect(manual_network).to receive(:configure)
          expect(dynamic_network).to receive(:configure)
          expect(vip_network).to_not receive(:configure)

          cloud = mock_cloud do |openstack|
            expect(openstack).to receive(:addresses).and_return([address])
          end
          expect(address).to_not receive(:server=).with(nil)

          network_configurator = Bosh::OpenStackCloud::NetworkConfigurator.new(network_spec)
          network_configurator.configure(cloud.compute, other_server)
        end
      end
      context 'when no floating IP is associated' do
        it 'should not configure the vip_network' do
          expect(manual_network).to receive(:configure)
          expect(dynamic_network).to receive(:configure)
          expect(vip_network).to_not receive(:configure)
          cloud = mock_cloud do |openstack|
            expect(openstack).to receive(:addresses).and_return([])
          end

          network_configurator = Bosh::OpenStackCloud::NetworkConfigurator.new(network_spec)
          network_configurator.configure(cloud.compute, nil)
        end
      end
    end
  end
end
