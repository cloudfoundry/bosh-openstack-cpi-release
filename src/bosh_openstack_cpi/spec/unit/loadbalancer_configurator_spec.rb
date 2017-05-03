require 'spec_helper'
require 'fog/compute/openstack/models/server'

describe Bosh::OpenStackCloud::LoadbalancerConfigurator do
  subject(:subject) { Bosh::OpenStackCloud::LoadbalancerConfigurator.new(network_spec, openstack) }
  let(:network_spec) { {} }
  let(:openstack) { instance_double(Bosh::OpenStackCloud::Openstack) }
  let(:network) { double('network', list_lbaas_pools: loadbalancer_pools_response) }
  let(:loadbalancer_pools_response) { double('response', :body => body) }
  let(:body) {
    {
      'pools' => [
        { 'name' => 'my-lb-pool', 'id' => 'pool-id' }
      ]
    }
  }
  let(:server) { instance_double(Fog::Compute::OpenStack::Server, id: 1234) }
  let(:pool) {
    {
      'name' => 'my-lb-pool',
      'port' => 8080
    }
  }

  before(:each) do
    allow(openstack).to receive(:with_openstack) { |&block| block.call }
    allow(openstack).to receive(:network).and_return(network)
  end

  describe '#add_vm_to_pool' do

    context 'when pool input invalid' do
      it 'raises an error' do
        expect{
          subject.add_vm_to_pool(server, {'name' => 'foo'})
        }.to raise_error(Bosh::Clouds::VMCreationFailed, "VM with id '1234' cannot be attached to load balancer pool 'foo'. Reason: Load balancer pool 'foo' has no port definition")

        expect{
          subject.add_vm_to_pool(server, {'port' => 8080})
        }.to raise_error(Bosh::Clouds::VMCreationFailed, "VM with id '1234' cannot be attached to load balancer pool ''. Reason: Load balancer pool defined without a name")
      end
    end

    context 'when load balancer pool can not be associated to the VM' do
      context 'when load balancer pool name does not exist' do
        let(:body) { { 'pools' => [] } }

        it 'raises an error' do
          expect {
            subject.add_vm_to_pool(server, pool)
          }.to raise_error(Bosh::Clouds::VMCreationFailed, "VM with id '1234' cannot be attached to load balancer pool 'my-lb-pool'. Reason: Load balancer pool 'my-lb-pool' does not exist")
        end
      end

      context 'when load balancer pool name exists multiple times' do
        let(:body) {
          {
            'pools' => [
              { 'name' => 'my-lb-pool' },
              { 'name' => 'my-lb-pool' }
            ]
          }
        }
        it 'raises an error' do
          expect {
            subject.add_vm_to_pool(server, pool)
          }.to raise_error(Bosh::Clouds::VMCreationFailed, "VM with id '1234' cannot be attached to load balancer pool 'my-lb-pool'. Reason: Load balancer pool 'my-lb-pool' exists multiple times. Make sure to use unique naming.")
        end
      end
    end

    context 'when load balancer pool name exist exactly once' do
      before(:each) do
        allow(network).to receive(:create_lbaas_pool_member).and_return(lb_member)
      end

      let(:lb_member) { double('lb_member', id: 'id') }

      let(:network_spec) {
        {
          'network_a' => manual_network_spec(net_id: 'sub-net-id', ip: '10.10.10.10'),
          'vip_network' => vip_network_spec
        }
      }

      it 'adds the VM as a member of the specified pool' do
        allow(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:matching_gateway_subnet_ids_for_ip).and_return(['sub-net-id'])

        loadbalancer_membership = subject.add_vm_to_pool(server, pool)

        expect(network).to have_received(:create_lbaas_pool_member).with('pool-id', '10.10.10.10', 8080, { subnet_id: 'sub-net-id' })
        expect(loadbalancer_membership.membership_id).to eq('id')
        expect(loadbalancer_membership.port).to eq(8080)
        expect(loadbalancer_membership.name).to eq('my-lb-pool')
        expect(loadbalancer_membership.pool_id).to eq('pool-id')
      end
    end

    context 'when ip address cannot be determined' do
      before(:each) do
        allow(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:gateway_ip).and_raise(Bosh::Clouds::VMCreationFailed.new(false), 'Original message.')
      end

      it 'raises an error' do
        expect {
          subject.add_vm_to_pool(server, pool)
        }.to raise_error(Bosh::Clouds::VMCreationFailed, "VM with id '1234' cannot be attached to load balancer pool 'my-lb-pool'. Reason: Original message.")
      end
    end

    context 'when multiple subnet ids match' do
      let(:network_spec) {
        {
          'network_a' => manual_network_spec(net_id: 'net-id', ip: '10.10.10.10')
        }
      }

      it 'errors' do
        allow(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:matching_gateway_subnet_ids_for_ip).and_return(['subnet-id', 'other-subnet-id'])
        expect{
          subject.add_vm_to_pool(server, pool)
        }.to raise_error(Bosh::Clouds::VMCreationFailed, /Reason: In network 'net-id' more than one subnet CIDRs match the IP '10\.10\.10\.10'/)
      end
    end

    context 'when no subnet id match or no subnet exists' do
      let(:network_spec) {
        {
          'network_a' => manual_network_spec(net_id: 'net-id', ip: '10.10.10.10')
        }
      }

      it 'errors' do
        allow(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:matching_gateway_subnet_ids_for_ip).and_return([])
        expect{
          subject.add_vm_to_pool(server, pool)
        }.to raise_error(Bosh::Clouds::VMCreationFailed, /Network 'net-id' does not contain any subnet to match the IP '10\.10\.10\.10'/)
      end
    end
  end
end