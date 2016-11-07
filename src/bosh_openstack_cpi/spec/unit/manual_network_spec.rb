# Copyright (c) 2009-2013 VMware, Inc.

require 'spec_helper'

describe Bosh::OpenStackCloud::ManualNetwork do

  subject { Bosh::OpenStackCloud::ManualNetwork.new(network_name, network_spec) }

  describe '#initialize' do
    context 'when spec is not a hash' do
      let(:network_name) { 'default' }
      let(:network_spec) { [] }
      it 'should fail' do
        expect {
          subject
        }.to raise_error ArgumentError, /Invalid spec, Hash expected/
      end
    end

    context 'when spec is a hash' do
      let(:network_name) { 'default' }
      let(:network_spec) {
        network_spec = manual_network_spec
        network_spec['ip'] = '172.20.214.10'
        network_spec
      }

      it 'should set the IP' do
        expect(subject.private_ip).to eq('172.20.214.10')
      end
    end
  end

  describe '#prepare' do
    let(:network_name) { 'network_a'}
    let(:network_spec) { manual_network_spec(ip: '10.0.0.1')}
    let(:security_groups_to_be_used) { ['default-security-group-id'] }

    context "with 'use_nova_networking=false'" do
      before(:each) do
        port_result_net = double('ports1', id: '117717c1-81cb-4ac4-96ab-99aaf1be9ca8', network_id: 'net', mac_address: 'AA:AA:AA:AA:AA:AA')
        allow(openstack).to receive(:network).and_return(neutron)
        allow(ports).to receive(:create).with(network_id: 'net', fixed_ips: [{ip_address: '10.0.0.1'}], security_groups: ['default-security-group-id']).and_return(port_result_net)
        allow(neutron).to receive(:ports).and_return(ports)
      end

      let(:neutron) { double(Fog::Network) }
      let(:openstack) { instance_double(Bosh::OpenStackCloud::Openstack, use_nova_networking?: false) }
      let(:ports) { double('Fog::Network::OpenStack::Ports') }

      it 'adds port_ids to nic' do
        #TODO create chore in order to check security group handling (i.e. we set all sec groups on all ports currently)
        subject.prepare(openstack, security_groups_to_be_used)

        expect(subject.nic).to eq({'net_id' => 'net', 'port_id' => '117717c1-81cb-4ac4-96ab-99aaf1be9ca8'})
      end

      it 'adds MAC addresses to network spec' do
        subject.prepare(openstack, security_groups_to_be_used)

        expect(subject.spec['mac']).to eq('AA:AA:AA:AA:AA:AA')
      end

      it 'sets the given security groups for the port' do
        subject.prepare(openstack, security_groups_to_be_used)

        expect(ports).to have_received(:create).with(network_id: anything, fixed_ips: anything, security_groups: ['default-security-group-id'])
      end

    end

    context "with 'use_nova_networking=true'" do
      let(:manual_network) { manual_network_spec(ip: '10.0.0.1')}
      let(:security_groups_to_be_used) { ['default-security-group-id'] }

      let(:openstack) { instance_double(Bosh::OpenStackCloud::Openstack, use_nova_networking?: true, network: double('Fog::Network')) }

      it 'does not use Fog::Network' do
        subject.prepare(openstack, security_groups_to_be_used)

        expect(openstack).to_not have_received(:network)
      end

      it "adds 'v4_fixed_ip' to nic" do
        subject.prepare(openstack, security_groups_to_be_used)

        expect(subject.nic).to eq({'net_id' => 'net', 'v4_fixed_ip' => '10.0.0.1'})
      end
    end

  end

  describe '#cleanup' do
    let(:network_name) { 'network_a'}
    let(:network_spec) { manual_network_spec(ip: '10.0.0.1')}

    context "with 'use_nova_networking=false'" do

      before(:each) do
        allow(openstack).to receive(:network).and_return(neutron)
        allow(ports).to receive(:create).with(network_id: 'net', fixed_ips: [{ip_address: '10.0.0.1'}], security_groups: []).and_return(port)
        allow(ports).to receive(:get).with('117717c1-81cb-4ac4-96ab-99aaf1be9ca8').and_return(port)
        allow(neutron).to receive(:ports).and_return(ports)
      end

      let(:port) { double('ports1', id: '117717c1-81cb-4ac4-96ab-99aaf1be9ca8', network_id: 'net', mac_address: 'AA:AA:AA:AA:AA:AA', destroy: nil) }
      let(:neutron) { double(Fog::Network) }
      let(:openstack) { instance_double(Bosh::OpenStackCloud::Openstack, use_nova_networking?: false, network: double('Fog::Network')) }
      let(:ports) { double('Fog::Network::OpenStack::Ports') }

      before(:each) do
        subject.prepare(openstack, [])
      end

      it 'should delete port' do
        subject.cleanup(openstack)

        expect(port).to have_received(:destroy)
      end

      context 'when ports are destroyed by OpenStack (versions < Mitaka)' do
        before(:each) do
          allow(ports).to receive(:get).with('117717c1-81cb-4ac4-96ab-99aaf1be9ca8').and_return(nil)
        end

        it 'should not fail try to destroy port' do
          expect {
            subject.cleanup(openstack)
          }.to_not raise_error
        end
      end
    end

    context "with 'use_nova_networking=true'" do
      let(:openstack) { instance_double(Bosh::OpenStackCloud::Openstack, use_nova_networking?: true, network: double('Fog::Network')) }
      let(:security_groups_to_be_used) { [] }

      before(:each) do
        subject.prepare(openstack, [])
      end

      it 'should not call Fog::Network' do
        subject.cleanup(openstack)

        expect(openstack).to_not have_received(:network)
      end
    end
  end
end
