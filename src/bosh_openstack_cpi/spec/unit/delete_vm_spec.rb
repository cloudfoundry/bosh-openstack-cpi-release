require 'spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  let(:registry_key) { 'vm-registry-key' }

  let(:server_metadata) do
    [
      double('metadatum', key: 'lbaas_pool_0', value: 'pool-id-0/membership-id-0'),
      double('metadatum', key: 'job', value: 'bosh'),
      double('metadatum', key: 'registry_key', value: registry_key),
    ]
  end

  let(:server) { double('server', id: 'i-foobar', name: 'i-foobar', metadata: server_metadata) }
  let(:cloud) do
    mock_cloud do |fog|
      allow(fog.compute.servers).to receive(:get).with('i-foobar').and_return(server)
    end
  end

  let(:loadbalancer_configurator) { instance_double(Bosh::OpenStackCloud::LoadbalancerConfigurator) }

  let(:server_groups) { instance_double(Bosh::OpenStackCloud::ServerGroups) }

  before(:each) do
    @registry = mock_registry
    Bosh::Clouds::Config.configure(double('config', uuid: 'director-uuid'))

    allow(Bosh::Clouds::Config).to receive(:uuid).and_return('fake-uuid')
    allow(Bosh::OpenStackCloud::ServerGroups).to receive(:new).and_return(server_groups)
    allow(server_groups).to receive(:delete_if_no_members)
    allow(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:port_ids).and_return(['port_id'])
    allow(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:cleanup_ports)
    allow(server).to receive(:destroy)
    allow(cloud.openstack).to receive(:wait_resource)
    allow(@registry).to receive(:delete_settings)
    allow(Bosh::OpenStackCloud::LoadbalancerConfigurator).to receive(:new).and_return(loadbalancer_configurator)
    allow(loadbalancer_configurator).to receive(:cleanup_memberships)
  end

  context 'when server retrieval fails' do
    let(:cloud) do
      mock_cloud do |fog|
        allow(fog.compute.servers).to receive(:get).with('i-foobar').and_raise('BOOM!')
      end
    end

    it 'stops and raises' do
      expect {
        cloud.delete_vm('i-foobar')
      }.to raise_error('BOOM!')
    end
  end

  context 'when server cannot be found' do
    let(:cloud) do
      mock_cloud do |fog|
        allow(fog.compute.servers).to receive(:get).with('i-foobar').and_return(nil)
      end
    end

    before(:each) do
      allow(Bosh::Clouds::Config.logger).to receive(:info)
    end

    it 'stops and logs' do
      cloud.delete_vm('i-foobar')

      expect(Bosh::Clouds::Config.logger).to have_received(:info).with('Server `i-foobar\' not found. Skipping.')
    end
  end

  it 'deletes an OpenStack server after removing the lbaas pool membership' do
    cloud.delete_vm('i-foobar')

    expect(loadbalancer_configurator).to have_received(:cleanup_memberships).with(
      'lbaas_pool_0' => 'pool-id-0/membership-id-0',
      'job' => 'bosh',
      'registry_key' => 'vm-registry-key',
    ).ordered
    expect(server).to have_received(:destroy).ordered
    expect(cloud.openstack).to have_received(:wait_resource).with(server, %i[terminated deleted], :state, true).ordered
    expect(Bosh::OpenStackCloud::NetworkConfigurator).to have_received(:cleanup_ports).with(any_args, ['port_id']).ordered
    expect(@registry).to have_received(:delete_settings).with(registry_key)
  end

  it 'deletes the server group after destroying the server' do
    cloud.delete_vm('i-foobar')

    expect(server).to have_received(:destroy).ordered
    expect(cloud.openstack).to have_received(:wait_resource).with(server, %i[terminated deleted], :state, true).ordered
    expect(server_groups).to have_received(:delete_if_no_members).ordered
  end

  context 'when server destroy fails' do
    it 'stops and raises' do
      allow(server).to receive(:destroy).and_raise('BOOM!')

      expect {
        cloud.delete_vm('i-foobar')
      }.to raise_error('BOOM!')
    end
  end

  context 'when getting ports fails' do
    it 'stops and raises' do
      allow(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:port_ids).and_raise('BOOM!')

      expect {
        cloud.delete_vm('i-foobar')
      }.to raise_error('BOOM!')
    end
  end

  context 'when port cleanup fails' do
    it 'does everything else but fails in the end' do
      allow(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:cleanup_ports).and_raise('BOOM!')

      expect {
        cloud.delete_vm('i-foobar')
      }.to raise_error(/BOOM!/)

      expect(@registry).to have_received(:delete_settings).with(registry_key)
      expect(loadbalancer_configurator).to have_received(:cleanup_memberships).with(
        'lbaas_pool_0' => 'pool-id-0/membership-id-0',
        'job' => 'bosh',
        'registry_key' => 'vm-registry-key',
      )
    end
  end

  context 'when destruction of LBaaS membership fails' do
    it 'does everything else and fails' do
      allow(loadbalancer_configurator).to receive(:cleanup_memberships).and_raise('BOOM!')

      expect {
        cloud.delete_vm('i-foobar')
      }.to raise_error(/BOOM!/)

      expect(Bosh::OpenStackCloud::NetworkConfigurator).to have_received(:cleanup_ports).with(any_args, ['port_id'])
      expect(@registry).to have_received(:delete_settings).with(registry_key)
    end
  end

  context 'when port cleanup and LBaaS membership cleanup fails' do
    it 'fails with both errors, but deletes the registry settings' do
      allow(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:cleanup_ports).and_raise('BOOM!')
      allow(loadbalancer_configurator).to receive(:cleanup_memberships).and_raise('BOOM!')

      expect {
        cloud.delete_vm('i-foobar')
      }.to raise_error(Bosh::Clouds::CloudError)

      expect(Bosh::OpenStackCloud::NetworkConfigurator).to have_received(:cleanup_ports).with(any_args, ['port_id'])
      expect(loadbalancer_configurator).to have_received(:cleanup_memberships).with(
        'lbaas_pool_0' => 'pool-id-0/membership-id-0',
        'job' => 'bosh',
        'registry_key' => 'vm-registry-key',
      )
      expect(@registry).to have_received(:delete_settings).with(registry_key)
    end
  end

  context 'when port cleanup, LBaaS membership cleanup and deleting settings from registry fails' do
    it 'fails with all errors and an aggregated error message containing the right prefixes' do
      allow(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:cleanup_ports).and_raise('BOOM1!')
      allow(loadbalancer_configurator).to receive(:cleanup_memberships).and_raise('BOOM2!')
      allow(@registry).to receive(:delete_settings).and_raise('BOOM3!')

      expected_error_msg = <<~EOF
        Multiple cloud errors occurred:
        Removing ports: BOOM1!
        Removing lbaas pool memberships: BOOM2!
        Deleting registry settings: BOOM3!
      EOF

      expect {
        cloud.delete_vm('i-foobar')
      }.to raise_error(Bosh::Clouds::CloudError, expected_error_msg.chomp)
    end
  end

  context 'when server is not tagged with `registry_key`' do
    let(:server_metadata) do
      [
        double('metadatum', key: 'lbaas_pool_0', value: 'pool-id-0/membership-id-0'),
        double('metadatum', key: 'job', value: 'bosh'),
      ]
    end

    it 'uses the server name to delete registry settings' do
      cloud.delete_vm('i-foobar')

      expect(@registry).to have_received(:delete_settings).with(server.name)
    end
  end
end
