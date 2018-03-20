require 'spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  it 'creates an OpenStack snapshot' do
    unique_name = SecureRandom.uuid
    volume = double('volume', id: 'v-foobar')
    attachment = { 'device' => '/dev/vdc' }
    snapshot = double('snapshot', id: 'snap-foobar', update_metadata: nil)
    snapshot_params = {
      display_name: "snapshot-#{unique_name}",
      display_description: 'deployment/job/0/vdc',
      name: "snapshot-#{unique_name}",
      description: 'deployment/job/0/vdc',
      volume_id: 'v-foobar',
      force: true,
    }
    metadata = {
      agent_id: 'agent',
      instance_id: 'instance',
      director_name: 'Test Director',
      director_uuid: '6d06b0cc-2c08-43c5-95be-f1b2dd247e18',
      deployment: 'deployment',
      job: 'job',
      index: '0',
    }

    cloud = mock_cloud do |fog|
      expect(fog.volume.volumes).to receive(:get).with('v-foobar').and_return(volume)
      expect(fog.volume.snapshots).to receive(:new).with(snapshot_params).and_return(snapshot)
    end

    expect(cloud).to receive(:generate_unique_name).and_return(unique_name)

    expect(volume).to receive(:attachments).and_return([attachment])

    expect(snapshot).to receive(:save)

    expect(cloud.openstack).to receive(:wait_resource).with(snapshot, :available)

    expect(cloud.snapshot_disk('v-foobar', metadata)).to eq('snap-foobar')
  end

  context "when volume doesn't have any attachment" do
    let(:volume) { double('volume', id: 'v-foobar', attachments: [{}]) }

    it 'creates an OpenStack snapshot' do
      unique_name = SecureRandom.uuid
      snapshot = double('snapshot', id: 'snap-foobar', update_metadata: nil)
      snapshot_params = {
        display_name: "snapshot-#{unique_name}",
        display_description: 'deployment/job/0',
        name: "snapshot-#{unique_name}",
        description: 'deployment/job/0',
        volume_id: 'v-foobar',
        force: true,
      }
      metadata = {
        agent_id: 'agent',
        instance_id: 'instance',
        director_name: 'Test Director',
        director_uuid: '6d06b0cc-2c08-43c5-95be-f1b2dd247e18',
        deployment: 'deployment',
        job: 'job',
        index: '0',
      }

      cloud = mock_cloud do |fog|
        expect(fog.volume.volumes).to receive(:get).with('v-foobar').and_return(volume)
        expect(fog.volume.snapshots).to receive(:new).with(snapshot_params).and_return(snapshot)
      end

      expect(cloud).to receive(:generate_unique_name).and_return(unique_name)

      expect(snapshot).to receive(:save)

      expect(cloud.openstack).to receive(:wait_resource).with(snapshot, :available)

      expect(cloud.snapshot_disk('v-foobar', metadata)).to eq('snap-foobar')
    end
  end

  it 'handles string keys in metadata' do
    unique_name = SecureRandom.uuid
    volume = double('volume', id: 'v-foobar')
    snapshot = double('snapshot', id: 'snap-foobar', update_metadata: nil)
    snapshot_params = {
      display_name: "snapshot-#{unique_name}",
      display_description: 'deployment/job/0',
      name: "snapshot-#{unique_name}",
      description: 'deployment/job/0',
      volume_id: 'v-foobar',
      force: true,
    }
    metadata = {
      'agent_id' => 'agent',
      'instance_id' => 'instance',
      'director_name' => 'Test Director',
      'director_uuid' => '6d06b0cc-2c08-43c5-95be-f1b2dd247e18',
      'deployment' => 'deployment',
      'job' => 'job',
      'index' => '0',
    }

    cloud = mock_cloud do |fog|
      expect(fog.volume.volumes).to receive(:get).with('v-foobar').and_return(volume)
      expect(fog.volume.snapshots).to receive(:new).with(snapshot_params).and_return(snapshot)
    end

    expect(cloud).to receive(:generate_unique_name).and_return(unique_name)

    expect(volume).to receive(:attachments).and_return([{}])

    expect(snapshot).to receive(:save)

    expect(cloud.openstack).to receive(:wait_resource).with(snapshot, :available)

    expect(cloud.snapshot_disk('v-foobar', metadata)).to eq('snap-foobar')
  end

  it 'should raise an Exception if OpenStack volume is not found' do
    cloud = mock_cloud do |fog|
      expect(fog.volume.volumes).to receive(:get).with('v-foobar').and_return(nil)
    end

    expect {
      cloud.snapshot_disk('v-foobar', {})
    }.to raise_error(Bosh::Clouds::CloudError, "Volume `v-foobar' not found")
  end

  it 'creates snapshot metadata with converted metadata' do
    volume = double('volume', id: 'v-foobar', attachments: [])
    snapshot = double('snapshot', id: 'snap-foobar', save: nil, update_metadata: nil)
    cloud = mock_cloud do |fog|
      allow(fog.volume.volumes).to receive(:get).and_return(volume)
      allow(fog.volume.snapshots).to receive(:new).and_return(snapshot)
    end
    allow(cloud.openstack).to receive(:wait_resource)

    metadata = {
      'deployment' => 'deployment',
      'job' => 'job',
      'index' => 0,
      'director_name' => 'Test Director',
      'director_uuid' => '1234',
      'agent_id' => 'agent0',
      'instance_id' => 'some-uuid',
    }

    expected_snapshot_metadata = {
      'director' => 'Test Director',
      'director_uuid' => '1234',
      'deployment' => 'deployment',
      'instance_id' => 'some-uuid',
      'instance_index' => '0',
      'instance_name' => 'job/some-uuid',
      'agent_id' => 'agent0',
    }

    cloud.snapshot_disk('v-foobar', metadata)

    expect(snapshot).to have_received(:update_metadata).with(expected_snapshot_metadata)
  end

  it 'creates snapshot metadata keeping user-defined tags without changing them' do
    volume = double('volume', id: 'v-foobar', attachments: [])
    snapshot = double('snapshot', id: 'snap-foobar', save: nil, update_metadata: nil)
    cloud = mock_cloud do |fog|
      allow(fog.volume.volumes).to receive(:get).and_return(volume)
      allow(fog.volume.snapshots).to receive(:new).and_return(snapshot)
    end
    allow(cloud.openstack).to receive(:wait_resource)

    metadata = {
      'deployment' => 'deployment',
      'job' => 'job',
      'index' => 0,
      'director_name' => 'Test Director',
      'director_uuid' => '1234',
      'agent_id' => 'agent0',
      'instance_id' => 'some-uuid',
      'tag1' => 'value1',
      'tag2' => 'value2',
    }

    expected_snapshot_metadata = {
      'director' => 'Test Director',
      'director_uuid' => '1234',
      'deployment' => 'deployment',
      'instance_id' => 'some-uuid',
      'instance_index' => '0',
      'instance_name' => 'job/some-uuid',
      'agent_id' => 'agent0',
      'tag1' => 'value1',
      'tag2' => 'value2',
    }

    cloud.snapshot_disk('v-foobar', metadata)

    expect(snapshot).to have_received(:update_metadata).with(expected_snapshot_metadata)
  end
end
