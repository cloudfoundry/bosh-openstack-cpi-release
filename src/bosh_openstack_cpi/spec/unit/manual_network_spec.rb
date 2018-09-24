require 'spec_helper'

describe Bosh::OpenStackCloud::ManualNetwork do
  subject { Bosh::OpenStackCloud::ManualNetwork.new(network_name, network_spec) }
  let(:openstack) { double(Bosh::OpenStackCloud::Openstack) }

  before { allow(openstack).to receive(:with_openstack) { |&block| block.call } }

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
    let(:network_name) { 'network_a' }
    let(:network_spec) { manual_network_spec(ip: '10.0.0.1') }
    let(:security_groups_to_be_used) { ['default-security-group-id'] }

    context "with 'use_nova_networking=false'" do
      before(:each) do
        port_result_net = double('ports1', id: '117717c1-81cb-4ac4-96ab-99aaf1be9ca8', network_id: 'net', mac_address: 'AA:AA:AA:AA:AA:AA')
        allow(openstack).to receive(:network).and_return(neutron)
        allow(ports).to receive(:create).and_return(port_result_net)
        allow(neutron).to receive(:ports).and_return(ports)
      end

      let(:neutron) { double(Fog::Network) }
      let(:openstack) { instance_double(Bosh::OpenStackCloud::Openstack, use_nova_networking?: false) }
      let(:ports) { double('Fog::OpenStack::Network::Ports') }

      it 'adds port_ids to nic' do
        subject.prepare(openstack, security_groups_to_be_used)

        expect(subject.nic).to eq('net_id' => 'net', 'port_id' => '117717c1-81cb-4ac4-96ab-99aaf1be9ca8')
      end

      it 'adds MAC addresses to network spec' do
        subject.prepare(openstack, security_groups_to_be_used)

        expect(subject.spec['mac']).to eq('AA:AA:AA:AA:AA:AA')
      end

      it 'sets the given security groups for the port' do
        subject.prepare(openstack, security_groups_to_be_used)

        expect(ports).to have_received(:create).once.with(network_id: anything, fixed_ips: anything, security_groups: ['default-security-group-id'])
      end

      context 'allowed_address_pair' do
        context 'is configured' do
          let(:manual_network) { manual_network_spec(ip: '10.0.0.1') }
          let(:allowed_address_pairs) { '10.0.0.10' }

          before(:each) do
            subject.allowed_address_pairs = allowed_address_pairs
          end

          it 'configures allowed_address_pair to the port' do
            allow(ports).to receive(:all).and_return([{ 'name' => 'vrrp-port' }])

            subject.prepare(openstack, security_groups_to_be_used)

            expect(ports).to have_received(:create).once.with(network_id: anything, fixed_ips: anything, security_groups: ['default-security-group-id'], allowed_address_pairs: [{ ip_address: allowed_address_pairs }])
            expect(ports).to have_received(:all).with(fixed_ips: "ip_address=#{allowed_address_pairs}")
          end

          context 'and vrrp port does not exist' do
            it 'raises an error' do
              allow(ports).to receive(:all).and_return([])

              expect {
                subject.prepare(openstack, security_groups_to_be_used)
              }.to raise_error(Bosh::Clouds::CloudError, "Configured VRRP port with ip '#{allowed_address_pairs}' does not exist.")
            end
          end
        end

        context 'is not configured' do
          it 'configures allowed_address_pair to the port' do
            subject.prepare(openstack, security_groups_to_be_used)

            expect(ports).to have_received(:create).once.with(network_id: anything, fixed_ips: anything, security_groups: ['default-security-group-id'])
          end
        end
      end

      context 'when Excon::Error::Conflict is raised' do
        let(:error) { Excon::Error::Conflict.new('some error message') }
        let(:network_spec) { manual_network_spec(net_id: 'net', ip: '10.0.0.1') }
        let(:all_ports) {
          [
            double('port1', id: 'id-1', network_id: 'net', status: 'DOWN', device_id: '', device_owner: ''),
            double('port2', id: 'id-2', network_id: 'net', status: 'ACTIVE', device_id: '', device_owner: ''),
            double('port3', id: 'id-3', network_id: 'net', status: 'DOWN', device_id: 'd_id', device_owner: ''),
            double('port4', id: 'id-4', network_id: 'net', status: 'DOWN', device_id: '', device_owner: 'd_owner'),
            double('port5', id: 'id-5', network_id: 'net', status: 'ACTIVE', device_id: 'd_id', device_owner: 'd_owner'),
            double('port6', id: 'id-6', network_id: 'net', status: 'DOWN', device_id: '', device_owner: ''),
            double('port7', id: 'id-7', network_id: 'net', status: 'DOWN', device_id: 'd_id', device_owner: 'd_owner'),
            double('port8', id: 'id-8', network_id: 'net', status: 'ACTIVE', device_id: 'd_id', device_owner: ''),
            double('port9', id: 'id-9', network_id: 'net', status: 'ACTIVE', device_id: '', device_owner: 'd_owner'),
          ]
        }
        let(:new_port) { double('new-port', id: 'new-port-id', mac_address: 'mac') }

        before(:each) do
          retried = false
          allow(ports).to receive(:create) do
            unless retried
              retried = true
              raise error
            end

            new_port
          end

          allow(ports).to receive(:all).and_return(all_ports)
          allow(openstack).to receive(:parse_openstack_response).and_return('type' => 'IpAddressAlreadyAllocated')
          allow(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:cleanup_ports)
        end

        it 'retrieves ports with the correct filter' do
          subject.prepare(openstack, [])

          expect(ports).to have_received(:all).with(fixed_ips: [anything, network_id: 'net'])
        end

        it 'deletes only detached ports' do
          subject.prepare(openstack, [])

          expect(Bosh::OpenStackCloud::NetworkConfigurator).to have_received(:cleanup_ports)
            .once.with(openstack, %w[id-1 id-6])
        end

        context 'when it has retried once and the error persists' do
          it 're-raises the error' do
            allow(ports).to receive(:create).and_raise(error)
            allow(openstack).to receive(:parse_openstack_response).and_return('type' => 'IpAddressAlreadyAllocated')
            allow(ports).to receive(:all).and_return([])

            expect {
              subject.prepare(openstack, [])
            }.to raise_error(error)

            expect(ports).to have_received(:create).exactly(2).times
            expect(ports).to have_received(:all).once
          end
        end
      end
    end

    context "with 'use_nova_networking=true'" do
      let(:manual_network) { manual_network_spec(ip: '10.0.0.1') }
      let(:openstack) { instance_double(Bosh::OpenStackCloud::Openstack, use_nova_networking?: true, network: double('Fog::Network')) }

      it 'does not use Fog::Network' do
        subject.prepare(openstack, security_groups_to_be_used)

        expect(openstack).to_not have_received(:network)
      end

      it "adds 'v4_fixed_ip' to nic" do
        subject.prepare(openstack, security_groups_to_be_used)

        expect(subject.nic).to eq('net_id' => 'net', 'v4_fixed_ip' => '10.0.0.1')
      end
    end
  end

  describe '#cleanup' do
    let(:network_name) { 'network_a' }
    let(:network_spec) { manual_network_spec(ip: '10.0.0.1') }

    context "with 'use_nova_networking=false'" do
      before(:each) do
        allow(openstack).to receive(:network).and_return(neutron)
        allow(ports).to receive(:create).with(network_id: 'net', fixed_ips: [{ ip_address: '10.0.0.1' }], security_groups: []).and_return(port)
        allow(ports).to receive(:get).with('117717c1-81cb-4ac4-96ab-99aaf1be9ca8').and_return(port)
        allow(neutron).to receive(:ports).and_return(ports)
      end

      let(:port) { double('ports1', id: '117717c1-81cb-4ac4-96ab-99aaf1be9ca8', network_id: 'net', mac_address: 'AA:AA:AA:AA:AA:AA', destroy: nil) }
      let(:neutron) { double(Fog::Network) }
      let(:openstack) { instance_double(Bosh::OpenStackCloud::Openstack, use_nova_networking?: false, network: double('Fog::Network')) }
      let(:ports) { double('Fog::OpenStack::Network::Ports') }

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
