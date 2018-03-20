require_relative './spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  include Bosh::OpenStackCloud::Helpers

  let(:logger) { Logger.new(STDERR) }
  let(:cpi_for_cloud_props) { IntegrationConfig.new.create_cpi }
  let(:server_groups) { Bosh::OpenStackCloud::ServerGroups.new(cpi_for_cloud_props.openstack) }

  before(:all) do
    @config = IntegrationConfig.new
    skip('Tests for auto-anti-affinity are not activated.') unless @config.test_auto_anti_affinity
  end

  before(:each) do
    delegate = double('delegate', logger: logger)
    Bosh::Clouds::Config.configure(delegate)
    allow(Bosh::Clouds::Config).to receive(:logger).and_return(logger)
    remove_server_groups(cpi_for_cloud_props)
  end

  after do
    remove_server_groups(cpi_for_cloud_props)
  end

  it 'creates a server group' do
    id = server_groups.find_or_create('1', '2')

    server_group = cpi_for_cloud_props.compute.server_groups.find { |f| f.name == '1-2' }
    expect(server_group).to_not be_nil
    expect(server_group.id).to eq(id)
    expect(server_group.policies.length).to eq(1)
    expect(server_group.policies.first).to eq('soft-anti-affinity')
  end

  it 'returns existing id for server group of same name' do
    id = server_groups.find_or_create('1', '2')
    other_id = server_groups.find_or_create('1', '2')

    groups = cpi_for_cloud_props.compute.server_groups.select { |f| f.name == '1-2' }
    expect(id).to eq(other_id)
    expect(groups.length).to eq(1)
  end

  it 'creates a single server group when CPI tries to create server groups in parallel' do
    threads = (1..10).map do
      Thread.new do
        server_groups.find_or_create('1', '2')
      end
    end
    threads.each(&:join)
    server_groups = cpi_for_cloud_props.compute.server_groups
    expect(server_groups.length).to eq(1)
    server_group = cpi_for_cloud_props.compute.server_groups.find { |f| f.name == '1-2' }
    expect(server_group).to_not be_nil
  end

  it 'deletes a server group without any members' do
    server_groups.find_or_create('1', '2')
    server_group = cpi_for_cloud_props.compute.server_groups.find { |f| f.name == '1-2' }
    expect(server_group).to_not be_nil

    server_groups.delete_if_no_members('1', '2')
    server_group = cpi_for_cloud_props.compute.server_groups.find { |f| f.name == '1-2' }
    expect(server_group).to be_nil
  end
end
