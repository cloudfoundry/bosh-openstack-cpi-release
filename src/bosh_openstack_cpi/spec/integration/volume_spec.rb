require_relative './spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  include Bosh::OpenStackCloud::Helpers

  before(:all) do
    @config = IntegrationConfig.new
    @cpi_for_stemcell = @config.create_cpi
    @stemcell_id, = upload_stemcell(@cpi_for_stemcell, @config.stemcell_path)
  end

  after(:all) do
    @cpi_for_stemcell.delete_stemcell(@stemcell_id)
  end

  before { allow(Bosh::Cpi::RegistryClient).to receive(:new).and_return(double('registry').as_null_object) }

  let(:disk_metadata) do
    {
      'director' => 'Director',
      'deployment' => 'deployment',
      'instance_id' => 'instance',
      'job' => 'openstack_cpi_spec',
      'instance_index' => '0',
      'instance_name' => 'openstack_cpi_spec/instance',
      'attached_at' => '2017-08-23T16:13:00Z',
    }
  end

  let(:disk_snapshot_metadata) do
    {
      deployment: 'deployment',
      job: 'openstack_cpi_spec',
      index: 0,
      instance_id: 'instance',
      agent_id: 'agent',
      director_name: 'Director',
      director_uuid: '6d06b0cc-2c08-43c5-95be-f1b2dd247e18',
    }
  end

  let(:expected_snapshot_metadata) do
    {
      'director' => 'Director',
      'director_uuid' => '6d06b0cc-2c08-43c5-95be-f1b2dd247e18',
      'deployment' => 'deployment',
      'instance_id' => 'instance',
      'instance_index' => '0',
      'instance_name' => 'openstack_cpi_spec/instance',
      'agent_id' => 'agent',
    }
  end

  let(:cpi_for_vm) { @config.create_cpi }
  let(:openstack) { @config.create_openstack }

  let(:network_spec) do
    {
      'default' => {
        'type' => 'dynamic',
        'cloud_properties' => {
          'net_id' => @config.net_id,
        },
      },
    }
  end

  let(:vm_id) do
    cpi_for_vm.create_vm(
      'agent-007',
      @stemcell_id,
      {
        'instance_type' => @config.instance_type,
        'availability_zone' => @config.availability_zone,
      },
      network_spec,
      [],
      'key' => 'value',
    )
  end

  let(:cloud_properties) { {} }

  let(:supported_volume_type) { cpi_for_vm.volume.volume_types.first.name }

  after(:each) do
    cpi_for_vm.delete_vm(vm_id)
  end

  describe 'Cinder V2 support' do
    context 'with NO global default_volume_type' do
      let(:cpi_for_volume) { @config.create_cpi }

      context 'and NO vm_type `type`' do
        it 'sets to nil' do
          expect(cpi_for_volume.volume.class.to_s).to start_with('Fog::Volume::OpenStack::V2')
          volume_lifecycle
        end
      end

      context 'and with vm_type `type`' do
        let(:cloud_properties) { { 'type' => supported_volume_type } }

        it 'sets to volumes_ceph' do
          expect(cpi_for_volume.volume.class.to_s).to start_with('Fog::Volume::OpenStack::V2')
          volume_lifecycle(supported_volume_type)
        end
      end
    end

    context 'with global default_volume_type' do
      context 'and vm_type `type`' do
        let(:cpi_for_volume) { @config.create_cpi(default_volume_type: 'type-to-override') }
        let(:cloud_properties) { { 'type' => supported_volume_type } }

        it 'overrides to type' do
          expect(cpi_for_volume.volume.class.to_s).to start_with('Fog::Volume::OpenStack::V2')
          volume_lifecycle(supported_volume_type)
        end
      end

      context 'and NO vm_type `type`' do
        let(:cpi_for_volume) { @config.create_cpi(default_volume_type: supported_volume_type) }

        it 'uses the default_volume_type' do
          expect(cpi_for_volume.volume.class.to_s).to start_with('Fog::Volume::OpenStack::V2')
          volume_lifecycle(supported_volume_type)
        end
      end
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

  def volume_lifecycle(volume_type = nil)
    expect(vm_id).to_not be_nil

    disk_id = cpi_for_volume.create_disk(2048, cloud_properties, vm_id)
    expect(disk_id).to be

    expect(cpi_for_volume.has_disk?(disk_id)).to be(true)

    expect(openstack.volume.volumes.get(disk_id).volume_type).to eq(volume_type) unless volume_type.nil?

    cpi_for_volume.attach_disk(vm_id, disk_id)

    cpi_for_volume.set_disk_metadata(disk_id, disk_metadata)
    expect(cpi_for_volume.volume.volumes.get(disk_id).metadata).to include(disk_metadata)

    disk_snapshot_id = cpi_for_volume.snapshot_disk(disk_id, disk_snapshot_metadata)
    expect(disk_snapshot_id).to be
    expect(cpi_for_volume.volume.snapshots.get(disk_snapshot_id).metadata).to eq(expected_snapshot_metadata)

    cpi_for_volume.delete_snapshot(disk_snapshot_id)
    cpi_for_volume.detach_disk(vm_id, disk_id)
    cpi_for_volume.delete_disk(disk_id)
  end

  def force_volume_v1
    allow(Fog::Volume::OpenStack::V2).to receive(:new).and_raise(Fog::OpenStack::Errors::ServiceUnavailable)
  end
end
