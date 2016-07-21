require 'integration/spec_helper'
require 'cloud'
require 'logger'
require 'net/http'

describe Bosh::OpenStackCloud::Cloud do
  include Bosh::OpenStackCloud::Helpers

  before(:all) do
    @logger                          = Logger.new(STDERR)
    @auth_url                        = LifecycleHelper.get_config(:auth_url_v2)
    @username                        = LifecycleHelper.get_config(:username)
    @api_key                         = LifecycleHelper.get_config(:api_key)
    @tenant                          = LifecycleHelper.get_config(:tenant)
    @stemcell_path                   = LifecycleHelper.get_config(:stemcell_path)
    @default_key_name                = LifecycleHelper.get_config(:default_key_name)
    @ignore_server_az                = LifecycleHelper.get_config(:ignore_server_az, 'false')
    @instance_type                   = LifecycleHelper.get_config(:instance_type, 'm1.small')
    @net_id                          = LifecycleHelper.get_config(:net_id)
    @volume_type                     = LifecycleHelper.get_config(:volume_type, nil)

    Bosh::Clouds::Config.configure(OpenStruct.new(:logger => @logger, :cpi_task_log => nil))
    @cpi_for_stemcell                = create_cpi
    @stemcell_id                     = upload_stemcell
  end

  after(:all) do
    @cpi_for_stemcell.delete_stemcell(@stemcell_id)
  end

  before { allow(Bosh::Cpi::RegistryClient).to receive(:new).and_return(double('registry').as_null_object) }

  def create_cpi
    described_class.new(
      'openstack' => {
        'auth_url' => @auth_url,
        'username' => @username,
        'api_key' => @api_key,
        'tenant' => @tenant,
        'region' => @region,
        'endpoint_type' => 'publicURL',
        'default_key_name' => @default_key_name,
        'default_security_groups' => %w(default),
        'wait_resource_poll_interval' => 5,
        'boot_from_volume' => false,
        'config_drive' => nil,
        'ignore_server_availability_zone' => str_to_bool(@ignore_server_az),
        'human_readable_vm_names' => false,
        'connection_options' => connection_options(additional_connection_options(@logger))
      },
      'registry' => {
        'endpoint' => 'fake',
        'user' => 'fake',
        'password' => 'fake'
      }
    )
  end

  def upload_stemcell
    stemcell_manifest = Psych.load_file(File.join(@stemcell_path, 'stemcell.MF'))
    @cpi_for_stemcell.create_stemcell(File.join(@stemcell_path, 'image'), stemcell_manifest['cloud_properties'])
  end

  let(:disk_snapshot_metadata) do
    {
      :deployment => 'deployment',
      :job => 'openstack_cpi_spec',
      :index => '0',
      :instance_id => 'instance',
      :agent_id => 'agent',
      :director_name => 'Director',
      :director_uuid => '6d06b0cc-2c08-43c5-95be-f1b2dd247e18',
    }
  end

  let(:cpi_for_volume) { create_cpi }

  let(:cpi_for_vm) { create_cpi }

  let(:network_spec) do
    {
      'default' => {
        'type' => 'dynamic',
        'cloud_properties' => {
          'net_id' => @net_id
        }
      }
    }
  end

  let(:vm_id) do
    cpi_for_vm.create_vm(
      'agent-007',
      @stemcell_id,
      { 'instance_type' => @instance_type },
      network_spec,
      [],
      { 'key' => 'value' }
    )
  end

  let(:cloud_properties) { { 'type' => @volume_type } }

  after(:each) do
    cpi_for_vm.delete_vm(vm_id)
  end

  describe 'Cinder V2 support' do
    before do
      expect(cpi_for_volume.volume.class.to_s).to start_with('Fog::Volume::OpenStack::V2')
    end

    it 'exercises the volume lifecycle' do
      volume_lifecycle
    end
  end

  describe 'Cinder V1 support' do
    before do
      force_volume_v1
    end

    it 'exercises the volume lifecycle' do
      volume_lifecycle
    end
  end

  def volume_lifecycle
    expect(vm_id).to_not be_nil

    disk_id = cpi_for_volume.create_disk(2048, cloud_properties, vm_id)
    expect(disk_id).to be

    expect(cpi_for_volume.has_disk?(disk_id)).to be(true)

    cpi_for_volume.attach_disk(vm_id, disk_id)

    disk_snapshot_id = cpi_for_volume.snapshot_disk(disk_id, disk_snapshot_metadata)
    expect(disk_snapshot_id).to be

    cpi_for_volume.delete_snapshot(disk_snapshot_id)

    cpi_for_volume.detach_disk(vm_id, disk_id)

    cpi_for_volume.delete_disk(disk_id)
  end

  def force_volume_v1
    LifecycleHelper.override_root_service_versions(port: 8776, auth_url: @auth_url) do |versions|
      versions.select { |v| v['id'].start_with?('v1.') }
    end
    connection_opts = {auth_url: @auth_url, tenant: @tenant, username: @username, api_key: @api_key}
    LifecycleHelper.override_token_v2_service_catalog(connection_opts) do |service_catalog|
      volume_v1_type = 'volume'
      service_catalog.reject { |service| service['type'].start_with?('volume') && service['type'] != volume_v1_type }
    end

    expect(cpi_for_volume.volume.class.to_s).to start_with('Fog::Volume::OpenStack::V1')
  end

  def str_to_bool(string)
    if string == 'true'
      true
    else
      false
    end
  end
end
