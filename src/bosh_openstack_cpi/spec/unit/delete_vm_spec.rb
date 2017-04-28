require 'spec_helper'

describe Bosh::OpenStackCloud::Cloud do

  let(:server_metadata) do
    [
      double('metadatum', :key => 'lbaas_pool_0', :value => 'pool-id-0/membership-id-0'),
      double('metadatum', :key => 'job', :value => 'bosh')
    ]
  end

  before(:each) do
     @registry = mock_registry
   end

  it 'deletes an OpenStack server' do
    server = double('server', :id => 'i-foobar', :name => 'i-foobar', :metadata => server_metadata)

    cloud = mock_cloud do |fog|
      allow(fog.compute.servers).to receive(:get).with('i-foobar').and_return(server)
    end

    allow(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:port_ids).and_return(['port_id'])
    allow(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:cleanup_ports)
    allow(server).to receive(:destroy)
    allow(cloud.openstack).to receive(:wait_resource)
    allow(@registry).to receive(:delete_settings)
    allow(Bosh::OpenStackCloud::LoadbalancerConfigurator).to receive(:cleanup_memberships)

    cloud.delete_vm('i-foobar')

    expect(server).to have_received(:destroy)
    expect(cloud.openstack).to have_received(:wait_resource).with(server, [:terminated, :deleted], :state, true)
    expect(Bosh::OpenStackCloud::NetworkConfigurator).to have_received(:cleanup_ports).with(any_args, ['port_id'])
    expect(@registry).to have_received(:delete_settings).with('i-foobar')
    expect(Bosh::OpenStackCloud::LoadbalancerConfigurator).to have_received(:cleanup_memberships).with(
      {
        'lbaas_pool_0' => 'pool-id-0/membership-id-0',
        'job' => 'bosh'
      }
    )
  end
end
