require 'spec_helper'
require 'fog/compute/openstack/models/server'

describe Bosh::OpenStackCloud::LoadbalancerConfigurator do
  shared_examples 'changing load balancer resource' do
    context 'when load balancer is in status PENDING_UPDATE' do
      let(:body) { { 'NeutronError' => { 'message' => 'Invalid state PENDING_UPDATE of loadbalancer resource 1234-abcd' } } }
      let(:response) { instance_double('response', body: JSON.dump(body)) }
      let(:state_timeout) { 10 }

      before do
        Timecop.freeze
        allow(network).to receive(openstack_method_name, &raise_times(2))
        allow(openstack).to receive(:state_timeout).and_return(state_timeout)
      end

      after do
        Timecop.return
      end

      it 'attempts to change resource again after load balancer has become active again' do
        expect(network).to receive(openstack_method_name).exactly(3)
        expect(openstack).to receive(:wait_resource).exactly(4)

        action.call
      end

      it 'logs the attempts' do
        allow(logger).to receive(:debug)
        expected_message = "Changing load balancer resource failed with 'omg pending_update', unsuccessful attempts: "

        action.call

        expect(logger).to have_received(:debug)
          .with(expected_message + "'1'")
          .with(expected_message + "'2'")
      end

      context 'when state_timeout has been reached exactly' do
        let(:expected_retries) { 2 }
        let(:start_time) { Time.local(2017) }
        let(:time_increment) { 1 }
        let(:state_timeout) { time_increment * expected_retries }

        before do
          allow(network).to receive(openstack_method_name, &raise_times(expected_retries))
          Timecop.freeze(start_time)
          allow(openstack).to receive(:wait_resource) do
            Timecop.freeze(Time.now + time_increment)
          end
        end

        it 'fails with a CloudError, containing elapsed time and number of attempts' do
          expect {
            action.call
          }.to raise_error Bosh::Clouds::CloudError, /Reason: Bosh::Clouds::CloudError Failed after #{expected_retries}.0s with #{expected_retries} attempts with 'omg pending_update'/

          expect(network).to have_received(openstack_method_name).exactly(expected_retries)
          expect(openstack).to have_received(:wait_resource).exactly(expected_retries)
        end
      end

      def raise_times(times)
        times_called = 0
        proc {
          times_called += 1
          raise Excon::Error::Conflict.new('omg pending_update', '', response) if times_called <= times
          success_response
        }
      end
    end
  end

  subject(:subject) { Bosh::OpenStackCloud::LoadbalancerConfigurator.new(openstack, logger) }
  let(:logger) { instance_double(Logger, debug: nil) }
  let(:network_spec) { {} }
  let(:options) { { 'auth_url' => '' } }
  let(:openstack) { Bosh::OpenStackCloud::Openstack.new(options) }
  let(:network) { double('network', list_lbaas_pools: loadbalancer_pools_response, get_lbaas_listener: lb_listener, get_lbaas_pool: lb_pool) }
  let(:lb_listener) { double('lb_listener', body: { 'listener' => { 'loadbalancers' => [{ 'id' => 'loadbalancer-id' }] } }) }
  let(:lb_pool) { double('lb_pool', body: { 'pool' => { 'loadbalancers' => [{ 'id' => 'loadbalancer-id' }] } }) }
  let(:loadbalancer_pools_response) { double('response', body: body) }
  let(:body) {
    {
      'pools' => [
        { 'name' => 'my-lb-pool', 'id' => 'pool-id' },
      ],
    }
  }
  let(:server) { instance_double(Fog::Compute::OpenStack::Server, id: 1234) }
  let(:pool) {
    {
      'name' => 'my-lb-pool',
      'port' => 8080,
    }
  }

  before(:each) do
    allow(openstack).to receive(:network).and_return(network)
    allow(openstack).to receive(:wait_resource)
  end

  describe '#create_pool_memberships' do
    context 'when a list of loadbalancer_pools is given' do
      let(:load_balancer_pools) {
        [
          { 'name' => 'my-pool-1', 'port' => 443 },
          { 'name' => 'my-pool-2', 'port' => 8080 },
        ]
      }

      let(:network_spec) {
        {
          'network_a' => manual_network_spec(net_id: 'sub-net-id', ip: '10.10.10.10'),
          'vip_network' => vip_network_spec,
        } }

      let(:lb_member) { double('lb_member', body: { 'member' => { 'id' => 'membership-id' } }) }

      it 'creates the memberships and returns the corresponding server_tags' do
        allow(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:matching_gateway_subnet_ids_for_ip).and_return(['sub-net-id'])
        allow(network).to receive(:create_lbaas_pool_member).and_return(lb_member)

        server_tags = subject.create_pool_memberships(server, network_spec, load_balancer_pools)

        expect(server_tags).to eq(
          'lbaas_pool_1' => 'pool-id/membership-id',
          'lbaas_pool_2' => 'pool-id/membership-id',
        )
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

  describe '#create_membership' do
    let(:lb_member) { double('lb_member', body: { 'member' => { 'id' => 'member-id' } }) }

    before(:each) do
      allow(logger).to receive(:info)
      allow(network).to receive(:create_lbaas_pool_member).and_return(lb_member)
    end

    it 'waits for loadbalancer to be active and returns the id of the existing membership' do
      loadbalancer = instance_double(Bosh::OpenStackCloud::LoadbalancerConfigurator::LoadBalancerResource, 'loadbalancer', provisioning_status: 'ACTIVE')
      allow(Bosh::OpenStackCloud::LoadbalancerConfigurator::LoadBalancerResource).to receive(:new).and_return(loadbalancer)

      membership_id = subject.create_membership('pool-id', '10.0.0.1', '8080', 'subnet-id')

      expect(membership_id).to eq('member-id')
      expect(network).to have_received(:get_lbaas_pool).with('pool-id')
      expect(Bosh::OpenStackCloud::LoadbalancerConfigurator::LoadBalancerResource).to have_received(:new).with('loadbalancer-id', openstack)
      expect(openstack).to have_received(:wait_resource).with(loadbalancer, :active, :provisioning_status).twice
    end

    it 'runs into time out while waiting for load balancer to be active before creating pool member' do
      loadbalancer = instance_double(Bosh::OpenStackCloud::LoadbalancerConfigurator::LoadBalancerResource, 'loadbalancer', provisioning_status: 'PENDING_UPDATE')
      allow(Bosh::OpenStackCloud::LoadbalancerConfigurator::LoadBalancerResource).to receive(:new).and_return(loadbalancer)
      allow(openstack).to receive(:wait_resource).with(loadbalancer, :active, :provisioning_status).and_raise(Bosh::Clouds::CloudError.new('Timed out waiting for load balancer to be ACTIVE'))

      expect {
        subject.create_membership('pool-id', '10.0.0.1', '8080', 'subnet-id')
      }.to raise_error(Bosh::Clouds::CloudError, /Timed out waiting for load balancer to be ACTIVE/)

      expect(network).to have_received(:get_lbaas_pool).with('pool-id')
      expect(network).to_not have_received(:create_lbaas_pool_member)
      expect(openstack).to have_received(:wait_resource).with(loadbalancer, :active, :provisioning_status).once
    end

    context 'when lbaas resource cannot be found' do
      before(:each) do
        allow(subject).to receive(:loadbalancer_id).and_raise(Bosh::OpenStackCloud::LoadbalancerConfigurator::LoadBalancerResource::NotFound, 'some-error-message')
      end

      it 'raises an error' do
        expect {
          subject.create_membership('pool-id', '10.0.0.1', '8080', 'subnet-id')
        }.to raise_error(Bosh::Clouds::VMCreationFailed, 'some-error-message')

        expect(network).to_not have_received(:create_lbaas_pool_member)
      end
    end

    context 'when lbaas resources are not in a valid state e.g. pool has more than one loadbalancer associated' do
      before(:each) do
        allow(subject).to receive(:loadbalancer_id).and_raise(Bosh::OpenStackCloud::LoadbalancerConfigurator::LoadBalancerResource::NotSupportedConfiguration, 'some-error-message')
      end

      it 'raises an error' do
        expect {
          subject.create_membership('pool-id', '10.0.0.1', '8080', 'subnet-id')
        }.to raise_error(Bosh::Clouds::VMCreationFailed, 'some-error-message')
        expect(network).to_not have_received(:create_lbaas_pool_member)
      end
    end

    context 'when pool membership cannot be created' do
      let(:members) {
        double('lb_member', body: {
          'members' => [
            { 'id' => 'member-id-1', 'subnet_id' => 'subnet-id', 'address' => '10.0.0.2', 'protocol_port' => '8080' },
            { 'id' => 'member-id-2', 'subnet_id' => 'subnet-id', 'address' => '10.0.0.1', 'protocol_port' => '8080' },
          ],
        }) }

      let(:body) { {} }
      let(:response) { instance_double('response', body: JSON.dump(body)) }

      before(:each) do
        allow(network).to receive(:create_lbaas_pool_member).and_raise(Excon::Error::Conflict.new('BAM!', '', response))
        allow(network).to receive(:list_lbaas_pool_members).with('pool-id').and_return(members)
      end

      context 'when the membership already exists' do
        it 'returns the id of the existing membership' do
          membership_id = subject.create_membership('pool-id', '10.0.0.1', '8080', 'subnet-id')

          expect(membership_id).to eq('member-id-2')
        end

        it 'logs the fact' do
          subject.create_membership('pool-id', '10.0.0.1', '8080', 'subnet-id')

          expect(logger).to have_received(:info).with("Load balancer pool membership with pool id 'pool-id', ip '10.0.0.1', and port '8080' already exists. The membership has the id 'member-id-2'.")
        end
      end

      context 'when the membership supposedly exists, but cannot be matched' do
        it 'returns an error' do
          expect {
            subject.create_membership('pool-id', 'wrong-ip', '8080', 'subnet-id')
          }.to raise_error(Bosh::Clouds::CloudError, "Load balancer pool membership with pool id 'pool-id', ip 'wrong-ip', and port '8080' supposedly exists, but cannot be found.")
        end
      end

      it_behaves_like('changing load balancer resource') do
        let(:success_response) { double('lb_member', body: { 'member' => { 'id' => 'member-id' } }) }
        let(:openstack_method_name) { :create_lbaas_pool_member }
        let(:action) {
          -> { subject.create_membership('pool-id', 'wrong-ip', '8080', 'subnet-id') }
        }
      end
    end
  end

  describe '#add_vm_to_pool' do
    context 'when pool input invalid' do
      it 'raises an error' do
        expect {
          subject.add_vm_to_pool(server, network_spec, 'name' => 'foo')
        }.to raise_error(Bosh::Clouds::VMCreationFailed, "VM with id '1234' cannot be attached to load balancer pool 'foo'. Reason: Load balancer pool 'foo' has no port definition")

        expect {
          subject.add_vm_to_pool(server, network_spec, 'port' => 8080)
        }.to raise_error(Bosh::Clouds::VMCreationFailed, "VM with id '1234' cannot be attached to load balancer pool ''. Reason: Load balancer pool defined without a name")
      end
    end

    context 'when create_membership raises an error' do
      let(:network_spec) {
        {
          'network_a' => manual_network_spec(net_id: 'sub-net-id', ip: '10.10.10.10'),
        }
      }

      before(:each) do
        allow(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:matching_gateway_subnet_ids_for_ip).and_return(['sub-net-id'])
        allow(subject).to receive(:create_membership).and_raise(Bosh::Clouds::VMCreationFailed.new(false), 'some-error-message')
      end

      it 'raises an VMCreationFailed error' do
        expect {
          subject.add_vm_to_pool(server, network_spec, pool)
        }.to raise_error(Bosh::Clouds::VMCreationFailed, "VM with id '1234' cannot be attached to load balancer pool 'my-lb-pool'. Reason: some-error-message")
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
              { 'name' => 'my-lb-pool' },
            ],
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

      let(:lb_member) { double('lb_member', body: { 'member' => { 'id' => 'id' } }) }

      let(:network_spec) {
        {
          'network_a' => manual_network_spec(net_id: 'sub-net-id', ip: '10.10.10.10'),
          'vip_network' => vip_network_spec,
        }
      }

      it 'adds the VM as a member of the specified pool' do
        allow(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:matching_gateway_subnet_ids_for_ip).and_return(['sub-net-id'])

        loadbalancer_membership = subject.add_vm_to_pool(server, network_spec, pool)

        expect(network).to have_received(:create_lbaas_pool_member).with('pool-id', '10.10.10.10', 8080, subnet_id: 'sub-net-id')
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
          'network_a' => manual_network_spec(net_id: 'net-id', ip: '10.10.10.10'),
        }
      }

      it 'errors' do
        allow(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:matching_gateway_subnet_ids_for_ip).and_return(['subnet-id', 'other-subnet-id'])
        expect {
          subject.add_vm_to_pool(server, network_spec, pool)
        }.to raise_error(Bosh::Clouds::VMCreationFailed, /Reason: In network 'net-id' more than one subnet CIDRs match the IP '10\.10\.10\.10'/)
      end
    end

    context 'when no subnet id match or no subnet exists' do
      let(:network_spec) {
        {
          'network_a' => manual_network_spec(net_id: 'net-id', ip: '10.10.10.10'),
        }
      }

      it 'errors' do
        allow(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:matching_gateway_subnet_ids_for_ip).and_return([])
        expect {
          subject.add_vm_to_pool(server, network_spec, pool)
        }.to raise_error(Bosh::Clouds::VMCreationFailed, /Network 'net-id' does not contain any subnet to match the IP '10\.10\.10\.10'/)
      end
    end
  end

  describe '#remove_vm_from_pool' do
    let(:pool_id) { 'pool-id' }
    let(:membership_id) { 'membership-id' }

    before do
      allow(network).to receive(:delete_lbaas_pool_member)
    end

    it 'deletes load balancer pool membership' do
      loadbalancer = instance_double(Bosh::OpenStackCloud::LoadbalancerConfigurator::LoadBalancerResource, 'loadbalancer', provisioning_status: 'ACTIVE')
      allow(Bosh::OpenStackCloud::LoadbalancerConfigurator::LoadBalancerResource).to receive(:new).and_return(loadbalancer)

      subject.remove_vm_from_pool(pool_id, membership_id)

      expect(network).to have_received(:delete_lbaas_pool_member).with(pool_id, membership_id)
      expect(network).to have_received(:get_lbaas_pool).with('pool-id')
      expect(Bosh::OpenStackCloud::LoadbalancerConfigurator::LoadBalancerResource).to have_received(:new).with('loadbalancer-id', openstack)
      expect(openstack).to have_received(:wait_resource).with(loadbalancer, :active, :provisioning_status).twice
    end

    it 'runs into time out while waiting for load balancer to be active before deleting pool member' do
      loadbalancer = instance_double(Bosh::OpenStackCloud::LoadbalancerConfigurator::LoadBalancerResource, 'loadbalancer', provisioning_status: 'PENDING_UPDATE')
      allow(Bosh::OpenStackCloud::LoadbalancerConfigurator::LoadBalancerResource).to receive(:new).and_return(loadbalancer)
      allow(openstack).to receive(:wait_resource).with(loadbalancer, :active, :provisioning_status).and_raise(Bosh::Clouds::CloudError.new('Timed out waiting for load balancer to be ACTIVE'))

      expect {
        subject.remove_vm_from_pool(pool_id, membership_id)
      }.to raise_error(Bosh::Clouds::CloudError)

      expect(network).to_not have_received(:delete_lbaas_pool_member)
      expect(network).to have_received(:get_lbaas_pool).with('pool-id')
      expect(Bosh::OpenStackCloud::LoadbalancerConfigurator::LoadBalancerResource).to have_received(:new).with('loadbalancer-id', openstack)
      expect(openstack).to have_received(:wait_resource).with(loadbalancer, :active, :provisioning_status)
    end

    context 'when load balancer resources are not in a valid state e.g. pool has more than one loadbalancer associated' do
      before(:each) do
        allow(subject).to receive(:loadbalancer_id).and_raise(Bosh::OpenStackCloud::LoadbalancerConfigurator::LoadBalancerResource::NotSupportedConfiguration)
      end

      it 'raises an error' do
        expect {
          subject.remove_vm_from_pool(pool_id, membership_id)
        }.to raise_error(Bosh::Clouds::CloudError, /Deleting load balancer pool membership with pool_id 'pool-id' and membership_id 'membership-id' failed/)

        expect(network).to_not have_received(:delete_lbaas_pool_member)
      end
    end

    context 'when load balancer resource cannot be found' do
      before(:each) do
        allow(subject).to receive(:loadbalancer_id).and_raise(Bosh::OpenStackCloud::LoadbalancerConfigurator::LoadBalancerResource::NotFound)
      end

      it 'does not raise' do
        expect {
          subject.remove_vm_from_pool(pool_id, membership_id)
        }.to_not raise_error
      end

      it 'does not try to delete the membership' do
        subject.remove_vm_from_pool(pool_id, membership_id)

        expect(network).to_not have_received(:delete_lbaas_pool_member)
      end

      it 'logs error' do
        subject.remove_vm_from_pool(pool_id, membership_id)

        expect(logger).to have_received(:debug).with(/Skipping deletion of load balancer pool membership because load balancer resource cannot be found./)
      end
    end

    context 'when membership not found' do
      before do
        allow(network).to receive(:delete_lbaas_pool_member).and_raise(Fog::Network::OpenStack::NotFound)
      end

      it 'does not raise' do
        expect {
          subject.remove_vm_from_pool(pool_id, membership_id)
        }.to_not raise_error
      end

      it 'logs error' do
        expect {
          subject.remove_vm_from_pool(pool_id, membership_id)
        }.to_not raise_error

        expect(logger).to have_received(:debug).with("Skipping deletion of load balancer pool membership. Member with pool_id 'pool-id' and membership_id 'membership-id' does not exist.")
      end
    end

    context 'when membership deletion fails' do
      it 're-raises as CloudError' do
        allow(network).to receive(:delete_lbaas_pool_member).and_raise(Fog::Network::OpenStack::Error.new('BOOM!!!'))

        expect {
          subject.remove_vm_from_pool(pool_id, membership_id)
        }.to raise_error(Bosh::Clouds::CloudError, "Deleting load balancer pool membership with pool_id 'pool-id' and membership_id 'membership-id' failed. Reason: Fog::Network::OpenStack::Error BOOM!!!")
      end
    end

    it_behaves_like('changing load balancer resource') do
      let(:success_response) { double('lb_member', body: { 'member' => { 'id' => 'member-id' } }) }
      let(:openstack_method_name) { :delete_lbaas_pool_member }
      let(:action) {
        -> { subject.remove_vm_from_pool(pool_id, membership_id) }
      }
    end
  end

  describe '#loadbalancer_id' do
    let(:pool_id) { 'pool-id' }

    context 'when pool exists' do
      it 'returns the loadbalancer_id' do
        loadbalancer_id = subject.loadbalancer_id(pool_id)

        expect(loadbalancer_id).to eq('loadbalancer-id')
      end

      context 'when pool has no loadbalancer associated' do
        let(:lb_pool) { double('lb_pool', body: { 'pool' => { 'loadbalancers' => [] } }) }

        it 'raises an error' do
          expect {
            subject.loadbalancer_id(pool_id)
          }.to raise_error Bosh::OpenStackCloud::LoadbalancerConfigurator::LoadBalancerResource::NotFound, "No load balancers associated with load balancer pool 'pool-id'"
        end
      end

      context 'when pool has more than one loadbalancer associated' do
        let(:lb_pool) { double('lb_pool', body: { 'pool' => { 'loadbalancers' => [{ 'id' => 'loadbalancer-id-1' }, { 'id' => 'loadbalancer-id-2' }] } }) }

        it 'raises an error' do
          expect {
            subject.loadbalancer_id(pool_id)
          }.to raise_error(Bosh::OpenStackCloud::LoadbalancerConfigurator::LoadBalancerResource::NotSupportedConfiguration, "More than one load balancer is associated with load balancer pool 'pool-id'. It is not possible to verify the status of the load balancer responsible for the pool membership.")
        end
      end

      context 'when pool does not have loadbalancer property (before Newton)' do
        context 'when listener does exist' do
          let(:lb_pool) { double('lb_pool', body: { 'pool' => { 'loadbalancers' => nil, 'listeners' => [{ 'id' => 'listener-id' }] } }) }

          it 'returns loadbalancer id ' do
            loadbalancer_id = subject.loadbalancer_id(pool_id)

            expect(loadbalancer_id).to eq('loadbalancer-id')
            expect(network).to have_received(:get_lbaas_listener).with('listener-id')
          end
        end

        context 'when listener does not exist' do
          let(:lb_pool) { double('lb_pool', body: { 'pool' => { 'loadbalancers' => nil, 'listeners' => [] } }) }

          it 'raises an error' do
            expect {
              subject.loadbalancer_id(pool_id)
            }.to raise_error Bosh::OpenStackCloud::LoadbalancerConfigurator::LoadBalancerResource::NotFound, "No listeners associated with load balancer pool 'pool-id'"
          end
        end

        context 'when multiple listeners do exist' do
          let(:lb_pool) do
            double('lb_pool', body: { 'pool' => { 'loadbalancers' => nil, 'listeners' => [
                     { 'id' => 'listener-id' },
                     { 'id' => 'other-listener-id' },
                   ] } })
          end

          it 'raises an error' do
            expect {
              subject.loadbalancer_id(pool_id)
            }.to raise_error Bosh::OpenStackCloud::LoadbalancerConfigurator::LoadBalancerResource::NotSupportedConfiguration, "More than one listener is associated with load balancer pool 'pool-id'. It is not possible to verify the status of the load balancer responsible for the pool membership."
          end
        end
      end
    end

    context 'when pool does not exist' do
      before(:each) do
        allow(network).to receive(:get_lbaas_pool).and_raise(Fog::Network::OpenStack::NotFound.new, 'some-error-message')
      end

      it 'raises an error' do
        expect {
          subject.loadbalancer_id(pool_id)
        }.to raise_error Bosh::OpenStackCloud::LoadbalancerConfigurator::LoadBalancerResource::NotFound, "Load balancer ID could not be determined because pool with ID 'pool-id' was not found. Reason: some-error-message"
      end
    end
  end

  describe '#cleanup_memberships' do
    let(:server_metadata) {
      {
        'lbaas_pool_0' => 'pool-id-0/membership-id-0',
        'lbaas_pool_1' => 'pool-id-1/membership-id-1',
        'index' => 0,
        'job' => 'bosh',
      }
    }

    it 'removes all memberships found in server metadata' do
      allow(network).to receive(:delete_lbaas_pool_member).with('pool-id-0', 'membership-id-0')
      allow(network).to receive(:delete_lbaas_pool_member).with('pool-id-1', 'membership-id-1')

      subject.cleanup_memberships(server_metadata)

      expect(network).to have_received(:delete_lbaas_pool_member).with('pool-id-0', 'membership-id-0')
      expect(network).to have_received(:delete_lbaas_pool_member).with('pool-id-1', 'membership-id-1')
    end

    it 're-raises the exception' do
      allow(network).to receive(:delete_lbaas_pool_member).and_raise(Fog::Network::OpenStack::Error.new('BOOM!!!'))

      expect {
        subject.cleanup_memberships(server_metadata)
      }.to raise_error(Bosh::Clouds::CloudError)
    end
  end

  describe Bosh::OpenStackCloud::LoadbalancerConfigurator::LoadBalancerResource do
    let(:subject) { Bosh::OpenStackCloud::LoadbalancerConfigurator::LoadBalancerResource.new('loadbalancer-id', openstack) }
    let(:loadbalancer) { double('loadbalancer', body: { 'loadbalancer' => { 'id' => 'loadbalancer-id', 'provisioning_status' => 'ACTIVE' } }) }

    describe '#provisioning_status' do
      it 'returns the status of the loadbalancer' do
        allow(network).to receive(:get_lbaas_loadbalancer).and_return(loadbalancer)

        provisioning_status = subject.provisioning_status

        expect(provisioning_status).to eq('ACTIVE')
        expect(network).to have_received(:get_lbaas_loadbalancer).with('loadbalancer-id')
      end
    end

    describe '#id' do
      it 'returns the id of the loadbalancer' do
        expect(subject.id).to eq('loadbalancer-id')
      end
    end

    describe '#reload' do
      it 'returns the id of the loadbalancer' do
        expect(subject.reload).to eq(true)
      end
    end
  end
end
