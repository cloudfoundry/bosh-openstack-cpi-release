require 'spec_helper'

describe Bosh::OpenStackCloud::FloatingIp do
  let(:logger) { double('logger', info: nil) }

  before(:each) {
    allow(Bosh::Clouds::Config).to receive(:logger).and_return(logger)
  }
  let(:network) { double('network', get_server: nil, list_floating_ips: nil, associate_floating_ip: nil, disassociate_floating_ip: nil, get_port: nil, ports: nil) }
  let(:compute) { double('compute', addresses: nil) }
  let(:openstack) { double('openstack', use_nova_networking?: use_nova_networking, network: network, compute: compute) }

  context 'when `use_nova_networking=false`' do
    let(:use_nova_networking) { false }

    let(:floating_ip_port_id) { 'old-server-port-id' }

    let(:floating_ips_response) {
      Struct.new(:body).new(
        'floatingips' => floating_ips,
      )
    }
    let(:floating_ips) {
      [
        {
          'floating_network_id' => 'some-floating-network-id',
          'router_id' => 'some-router-id',
          'fixed_ip_address' => 'some-fixed-ip-address',
          'floating_ip_address' => '1.2.3.4',
          'tenant_id' => 'some-tenant-id',
          'status' => 'some-status',
          'port_id' => floating_ip_port_id,
          'id' => 'floating-ip-id',
        },
      ]
    }

    let(:get_port_response) {
      Struct.new(:body).new(
        'port' => port,
      )
    }

    let(:port_device_id) { nil }

    let(:port) {
      {
        'device_id' => port_device_id,
      } }
    before(:each) {
      allow(network).to receive(:get_port).with(floating_ip_port_id).and_return(get_port_response)
    }

    let(:old_server) { {} }
    let(:get_server_response) {
      Struct.new(:body).new(
        'server' => old_server,
      )
    }
    before(:each) {
      allow(compute).to receive(:get_server_details).and_return(get_server_response)
    }

    let(:port_collection) { double('Fog::OpenStack::Network::Ports', all: [port_model]) }
    let(:port_model) { double('Fog::OpenStack::Network::Port', id: 'port-id') }

    before(:each) {
      allow(network).to receive(:ports).and_return(port_collection)
    }

    describe '.port_attached?' do
      context 'when the floating_ip port_id is nil' do
        let(:floating_ip) {
          {
            'port_id' => nil,
          }
        }
        it 'returns false' do
          expect(Bosh::OpenStackCloud::FloatingIp.port_attached?(floating_ip)).to be false
        end
      end
      context 'when the floating_ip port_id is empty' do
        let(:floating_ip) {
          {
            'port_id' => '',
          }
        }
        it 'returns false' do
          expect(Bosh::OpenStackCloud::FloatingIp.port_attached?(floating_ip)).to be false
        end
      end
      context 'when the floating_ip port_id is non-empty' do
        let(:floating_ip) {
          {
            'port_id' => floating_ip_port_id,
          }
        }
        it 'returns true' do
          expect(Bosh::OpenStackCloud::FloatingIp.port_attached?(floating_ip)).to be true
        end
      end
    end

    describe '.reassociate' do
      before(:each) {
        allow(network).to receive(:list_floating_ips).with('floating_ip_address' => '1.2.3.4').and_return(floating_ips_response)
      }

      let(:server) {
        Struct.new(:id, :name).new('server-id', 'server-name')
      }

      context 'when the floating ip is already associated with a port' do
        let(:port_device_id) { old_server['id'] }

        let(:old_server) {
          {
            'id' => 'old-server-id',
            'name' => 'old-server',
          }
        }

        it 'disassociates the floating ip and associates it with the given server' do
          Bosh::OpenStackCloud::FloatingIp.reassociate(openstack, '1.2.3.4', server, 'network-id')

          expect(network).to have_received(:list_floating_ips).with('floating_ip_address' => '1.2.3.4')

          expect(network).to have_received(:disassociate_floating_ip).with('floating-ip-id')
          expect(logger).to have_received(:info).with("Disassociating floating IP '1.2.3.4' from server 'old-server (old-server-id)'")
          expect(port_collection).to have_received(:all).with(device_id: 'server-id', network_id: 'network-id')
          expect(logger).to have_received(:info).with("Associating floating IP '1.2.3.4' with server 'server-name (server-id)'")
          expect(network).to have_received(:associate_floating_ip).with('floating-ip-id', 'port-id')
        end
      end

      context 'when the floating ip is not associated with a port' do
        let(:floating_ip_port_id) { nil }

        it 'assigns the given floating ip to the given server' do
          Bosh::OpenStackCloud::FloatingIp.reassociate(openstack, '1.2.3.4', server, 'network-id')

          expect(network).to have_received(:list_floating_ips).with('floating_ip_address' => '1.2.3.4')
          expect(port_collection).to have_received(:all).with(device_id: 'server-id', network_id: 'network-id')

          expect(network).to have_received(:associate_floating_ip).with('floating-ip-id', 'port-id')
        end

        context 'when multiple ports are connected to the external network' do
          before(:each) do
            allow(port_collection).to receive(:all).and_return([double('other_port', id: 'other-port-id'), port_model])
          end

          it 'assigns the given floating ip to the first port' do
            Bosh::OpenStackCloud::FloatingIp.reassociate(openstack, '1.2.3.4', server, 'network-id')

            expect(network).to have_received(:list_floating_ips).with('floating_ip_address' => '1.2.3.4')
            expect(port_collection).to have_received(:all).with(device_id: 'server-id', network_id: 'network-id')

            expect(network).to have_received(:associate_floating_ip).with('floating-ip-id', 'other-port-id')
          end
        end
      end

      context "openstack doesn't find the given floating ip" do
        let(:floating_ips) { [] }

        it 'raises a cloud error' do
          expect {
            Bosh::OpenStackCloud::FloatingIp.reassociate(openstack, '1.2.3.4', server, 'network-id')
          }.to raise_error Bosh::Clouds::CloudError, "Floating IP '1.2.3.4' not allocated"
        end
      end

      context 'openstack finds the given floating ip more than once' do
        let(:floating_ips) { [{ 'floating_network_id' => 'id1' }, { 'floating_network_id' => 'id2' }] }

        it 'raises a cloud error' do
          expect {
            Bosh::OpenStackCloud::FloatingIp.reassociate(openstack, '1.2.3.4', server, 'network-id')
          }.to raise_error Bosh::Clouds::CloudError, "Floating IP '1.2.3.4' found in multiple networks: 'id1', 'id2'"
        end
      end

      context 'server has no port in the given network' do
        before(:each) do
          allow(port_collection).to receive(:all).and_return([])
        end
        it 'raises a cloud error' do
          expect {
            Bosh::OpenStackCloud::FloatingIp.reassociate(openstack, '1.2.3.4', server, 'network-id-not-matching-the-port')
          }.to raise_error Bosh::Clouds::CloudError, "Server has no port in network 'network-id-not-matching-the-port'"
        end
      end
    end
  end

  context 'when `use_nova_networking=true`' do
    let(:use_nova_networking) { true }

    describe '.reassociate' do
      let(:server) {
        Struct.new(:id, :name).new('server-id', 'server-name')
      }

      before(:each) do
        allow(compute).to receive(:addresses).and_return([address])
      end

      let(:server) { double('server', id: 'i-test') }

      context 'ip already associated with an instance' do
        let(:address) do
          double('address', :server= => nil, :id => 'network_b', :ip => '1.2.3.4', :instance_id => 'old-instance-id')
        end

        it 'adds floating ip to the server for vip network' do
          Bosh::OpenStackCloud::FloatingIp.reassociate(openstack, '1.2.3.4', server, 'network-id')

          expect(logger).to have_received(:info).with("Disassociating floating IP '1.2.3.4' from server 'old-instance-id'")
          expect(address).to have_received(:server=).with(nil)
          expect(logger).to have_received(:info).with("Associating floating IP '1.2.3.4' with server 'i-test'")
          expect(address).to have_received(:server=).with(server)
        end
      end

      context 'ip not already associated with an instance' do
        let(:address) do
          double('address', :server= => nil, :id => 'network_b', :ip => '1.2.3.4', :instance_id => nil)
        end

        it 'adds free floating ip to the server for vip network' do
          Bosh::OpenStackCloud::FloatingIp.reassociate(openstack, '1.2.3.4', server, 'network-id')

          expect(address).to_not have_received(:server=).with(nil)
          expect(address).to have_received(:server=).with(server)
        end
      end

      context 'no floating IP allocated for vip network' do
        let(:address) do
          double('address', :server= => nil, :id => 'network_b', :ip => '10.0.0.2')
        end

        it 'fails' do
          expect {
            Bosh::OpenStackCloud::FloatingIp.reassociate(openstack, '1.2.3.4', server, 'network-id')
          }.to raise_error Bosh::Clouds::CloudError, /Floating IP .* not allocated/
        end
      end
    end
  end
end
