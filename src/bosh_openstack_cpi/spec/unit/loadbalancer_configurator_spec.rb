require 'spec_helper'
require 'fog/compute/openstack/models/server'

describe Bosh::OpenStackCloud::LoadbalancerConfigurator do
  subject(:subject) { Bosh::OpenStackCloud::LoadbalancerConfigurator.new(openstack, logger) }
  let(:logger) { instance_double(Logger, debug: nil) }
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

  describe '#create_pool_memberships' do
    context 'when a list of loadbalancer_pools is given' do

      let(:load_balancer_pools) { [
        { 'name' => 'my-pool-1', 'port' => 443 },
        { 'name' => 'my-pool-2', 'port' => 8080 }
      ] }

      let(:network_spec) { {
          'network_a' => manual_network_spec(net_id: 'sub-net-id', ip: '10.10.10.10'),
          'vip_network' => vip_network_spec
      } }

      let(:lb_member) { double('lb_member', body: {'member' => {'id' => 'membership-id'}}) }

      it 'creates the memberships and returns the corresponding server_tags' do
        allow(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:matching_gateway_subnet_ids_for_ip).and_return(['sub-net-id'])
        allow(network).to receive(:create_lbaas_pool_member).and_return(lb_member)

        server_tags = subject.create_pool_memberships(server, network_spec, load_balancer_pools)

        expect(server_tags).to eq({
          'lbaas_pool_1' => 'pool-id/membership-id',
          'lbaas_pool_2' => 'pool-id/membership-id'
        })
      end
    end

    context 'when the given list is empty' do
      it 'does nothing' do
        allow(network).to receive(:create_lbaas_pool_member)

        server_tags = subject.create_pool_memberships(server, network_spec, [])

        expect(server_tags).to eq({})
        expect(network).to_not have_received(:create_lbaas_pool_member)
      end
    end
  end

  describe '#add_vm_to_pool' do

    context 'when pool input invalid' do
      it 'raises an error' do
        expect{
          subject.add_vm_to_pool(server, network_spec, {'name' => 'foo'})
        }.to raise_error(Bosh::Clouds::VMCreationFailed, "VM with id '1234' cannot be attached to load balancer pool 'foo'. Reason: Load balancer pool 'foo' has no port definition")

        expect{
          subject.add_vm_to_pool(server, network_spec, {'port' => 8080})
        }.to raise_error(Bosh::Clouds::VMCreationFailed, "VM with id '1234' cannot be attached to load balancer pool ''. Reason: Load balancer pool defined without a name")
      end
    end

    context 'when load balancer pool can not be associated to the VM' do
      context 'when load balancer pool name does not exist' do
        let(:body) { { 'pools' => [] } }

        it 'raises an error' do
          expect {
            subject.add_vm_to_pool(server, network_spec, pool)
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
            subject.add_vm_to_pool(server, network_spec, pool)
          }.to raise_error(Bosh::Clouds::VMCreationFailed, "VM with id '1234' cannot be attached to load balancer pool 'my-lb-pool'. Reason: Load balancer pool 'my-lb-pool' exists multiple times. Make sure to use unique naming.")
        end
      end
    end

    context 'when load balancer pool name exist exactly once' do
      before(:each) do
        allow(network).to receive(:create_lbaas_pool_member).and_return(lb_member)
      end

      let(:lb_member) { double('lb_member', body: {'member' => {'id' => 'id'}}) }

      let(:network_spec) {
        {
          'network_a' => manual_network_spec(net_id: 'sub-net-id', ip: '10.10.10.10'),
          'vip_network' => vip_network_spec
        }
      }

      it 'adds the VM as a member of the specified pool' do
        allow(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:matching_gateway_subnet_ids_for_ip).and_return(['sub-net-id'])

        loadbalancer_membership = subject.add_vm_to_pool(server, network_spec, pool)

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
          subject.add_vm_to_pool(server, network_spec, pool)
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
          subject.add_vm_to_pool(server, network_spec, pool)
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
          subject.add_vm_to_pool(server, network_spec, pool)
        }.to raise_error(Bosh::Clouds::VMCreationFailed, /Network 'net-id' does not contain any subnet to match the IP '10\.10\.10\.10'/)
      end
    end
  end

  describe '#remove_vm_from_pool' do
    let(:pool_id) { 'pool-id' }
    let(:membership_id) { 'membership-id' }

    it 'deletes lbaas pool membership' do
      allow(network).to receive(:delete_lbaas_pool_member)

      subject.remove_vm_from_pool(pool_id, membership_id)

      expect(network).to have_received(:delete_lbaas_pool_member).with(pool_id, membership_id)
    end

    context 'when membership not found' do
      it 'does not raise' do
        allow(network).to receive(:delete_lbaas_pool_member).and_raise(Fog::Network::OpenStack::NotFound)

        expect{
          subject.remove_vm_from_pool(pool_id, membership_id)
        }.to_not raise_error
      end

      it 'logs error' do
        allow(network).to receive(:delete_lbaas_pool_member).and_raise(Fog::Network::OpenStack::NotFound)

        expect{
          subject.remove_vm_from_pool(pool_id, membership_id)
        }.to_not raise_error

        expect(logger).to have_received(:debug).with("Skipping deletion of lbaas pool member. Member with pool_id 'pool-id' and membership_id 'membership-id' does not exist.")
      end
    end

    context 'when membership deletion fails' do
      it 're-raises as CloudError' do
        allow(network).to receive(:delete_lbaas_pool_member).and_raise(Fog::Network::OpenStack::Error.new('BOOM!!!'))

        expect{
          subject.remove_vm_from_pool(pool_id, membership_id)
        }.to raise_error(Bosh::Clouds::CloudError, "Deleting LBaaS member with pool_id 'pool-id' and membership_id 'membership-id' failed. Reason: Fog::Network::OpenStack::Error BOOM!!!")
      end
    end
  end

  describe '#cleanup_memberships' do
    let(:server_metadata) {
      {
        'lbaas_pool_0' => 'pool-id-0/membership-id-0',
        'lbaas_pool_1' => 'pool-id-1/membership-id-1',
        'index' => 0,
        'job' => 'bosh'
      }
    }

    it "removes all memberships found in server metadata" do
      allow(network).to receive(:delete_lbaas_pool_member).with('pool-id-0', 'membership-id-0')
      allow(network).to receive(:delete_lbaas_pool_member).with('pool-id-1', 'membership-id-1')

      subject.cleanup_memberships(server_metadata)

      expect(network).to have_received(:delete_lbaas_pool_member).with('pool-id-0', 'membership-id-0')
      expect(network).to have_received(:delete_lbaas_pool_member).with('pool-id-1', 'membership-id-1')
    end

    it 're-raises the exception' do
      allow(network).to receive(:delete_lbaas_pool_member).and_raise(Fog::Network::OpenStack::Error.new('BOOM!!!'))

      expect{
        subject.cleanup_memberships(server_metadata)
      }.to raise_error(Bosh::Clouds::CloudError)
    end
  end
end