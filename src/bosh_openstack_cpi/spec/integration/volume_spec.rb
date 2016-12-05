require_relative './spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  include Bosh::OpenStackCloud::Helpers

  before(:all) do
    @config = IntegrationConfig.new
    @cpi_for_stemcell = @config.create_cpi
    @stemcell_id, _ = upload_stemcell(@cpi_for_stemcell, @config.stemcell_path)
  end

  after(:all) do
    @cpi_for_stemcell.delete_stemcell(@stemcell_id)
  end

  before { allow(Bosh::Cpi::RegistryClient).to receive(:new).and_return(double('registry').as_null_object) }

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

  let(:cpi_for_vm) { @config.create_cpi }

  let(:network_spec) do
    {
      'default' => {
        'type' => 'dynamic',
        'cloud_properties' => {
          'net_id' => @config.net_id
        }
      }
    }
  end

  let(:vm_id) do
    cpi_for_vm.create_vm(
      'agent-007',
      @stemcell_id,
      {
          'instance_type' => @config.instance_type,
          'availability_zone' => @config.availability_zone
      },
      network_spec,
      [],
      { 'key' => 'value' }
    )
  end

  let(:cloud_properties) { {
      'type' => @config.volume_type,
      'availability_zone' => @config.availability_zone
  } }

  after(:each) do
    cpi_for_vm.delete_vm(vm_id)
  end

  describe 'Cinder V2 support' do
    let(:cpi_for_volume) { @config.create_cpi }

    it 'exercises the volume lifecycle' do
      expect(cpi_for_volume.volume.class.to_s).to start_with('Fog::Volume::OpenStack::V2')
      volume_lifecycle
    end
  end

  describe 'Cinder V1 support' do
    let(:cpi_for_volume) { @config.create_cpi }
    before do
      force_volume_v1
    end

    it 'exercises the volume lifecycle' do
      expect(cpi_for_volume.volume.class.to_s).to start_with('Fog::Volume::OpenStack::V1')
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
    allow(Fog::Volume::OpenStack::V2).to receive(:new).and_raise(Fog::OpenStack::Errors::ServiceUnavailable)
  end

end
