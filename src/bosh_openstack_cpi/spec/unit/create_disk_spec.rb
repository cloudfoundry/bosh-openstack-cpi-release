require 'spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  describe 'connecting to the OpenStack Volume Service' do
    it 'connects when creating a volume' do
      unique_name = SecureRandom.uuid
      disk_params = {
        display_name: "volume-#{unique_name}",
        display_description: '',
        name: "volume-#{unique_name}",
        description: '',
        size: 2,
      }
      volume = double('volume', id: 'v-foobar')

      cloud = mock_cloud do |fog|
        allow(fog.volume.volumes).to receive(:create)
          .with(disk_params).and_return(volume)
      end

      allow(cloud).to receive(:generate_unique_name).and_return(unique_name)
      allow(cloud.openstack).to receive(:wait_resource).with(volume, :available)

      expect(Fog::Volume::OpenStack::V2).to receive(:new)
      expect(cloud.create_disk(2048, {})).to eq('v-foobar')
    end
  end

  it 'creates an OpenStack volume' do
    unique_name = SecureRandom.uuid
    disk_params = {
      display_name: "volume-#{unique_name}",
      display_description: '',
      name: "volume-#{unique_name}",
      description: '',
      size: 2,
    }
    volume = double('volume', id: 'v-foobar')

    cloud = mock_cloud do |fog|
      allow(fog.volume.volumes).to receive(:create)
        .with(disk_params).and_return(volume)
    end

    allow(cloud).to receive(:generate_unique_name).and_return(unique_name)
    allow(cloud.openstack).to receive(:wait_resource).with(volume, :available)

    expect(cloud.create_disk(2048, {})).to eq('v-foobar')
  end

  it 'creates an OpenStack volume with the specified volume_type' do
    unique_name = SecureRandom.uuid
    disk_params = {
      display_name: "volume-#{unique_name}",
      display_description: '',
      name: "volume-#{unique_name}",
      description: '',
      size: 2,
      volume_type: 'foo',
    }
    volume = double('volume', id: 'v-foobar')

    cloud = mock_cloud do |fog|
      expect(fog.volume.volumes).to receive(:create)
        .with(disk_params).and_return(volume)
    end

    expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
    expect(cloud.openstack).to receive(:wait_resource).with(volume, :available)

    expect(cloud.create_disk(2048, 'type' => 'foo')).to eq('v-foobar')
  end

  it 'creates an OpenStack volume with the default volume_type' do
    unique_name = SecureRandom.uuid
    disk_params = {
      display_name: "volume-#{unique_name}",
      display_description: '',
      name: "volume-#{unique_name}",
      description: '',
      size: 2,
      volume_type: 'default-type',
    }
    volume = double('volume', id: 'v-foobar')

    global_properties = mock_cloud_options['properties']
    global_properties['openstack']['default_volume_type'] = 'default-type'
    cloud = mock_cloud(global_properties) do |fog|
      expect(fog.volume.volumes).to receive(:create)
        .with(disk_params).and_return(volume)
    end

    expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
    expect(cloud.openstack).to receive(:wait_resource).with(volume, :available)

    expect(cloud.create_disk(2048, {})).to eq('v-foobar')
  end

  it 'rounds up disk size' do
    unique_name = SecureRandom.uuid
    disk_params = {
      display_name: "volume-#{unique_name}",
      display_description: '',
      name: "volume-#{unique_name}",
      description: '',
      size: 3,
    }
    volume = double('volume', id: 'v-foobar')

    cloud = mock_cloud do |fog|
      expect(fog.volume.volumes).to receive(:create)
        .with(disk_params).and_return(volume)
    end

    expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
    expect(cloud.openstack).to receive(:wait_resource).with(volume, :available)

    cloud.create_disk(2049, {})
  end

  it 'check min disk size' do
    expect {
      mock_cloud.create_disk(100, {})
    }.to raise_error(Bosh::Clouds::CloudError, /Minimum disk size is 1 GiB/)
  end

  it 'puts disk in the same AZ as a server' do
    unique_name = SecureRandom.uuid
    disk_params = {
      display_name: "volume-#{unique_name}",
      display_description: '',
      name: "volume-#{unique_name}",
      description: '',
      size: 1,
      availability_zone: 'foobar-land',
    }
    server = double('server', id: 'i-test',
                              availability_zone: 'foobar-land')
    volume = double('volume', id: 'v-foobar')

    cloud = mock_cloud do |fog|
      expect(fog.compute.servers).to receive(:get)
        .with('i-test').and_return(server)
      expect(fog.volume.volumes).to receive(:create)
        .with(disk_params).and_return(volume)
    end

    expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
    expect(cloud.openstack).to receive(:wait_resource).with(volume, :available)

    cloud.create_disk(1024, {}, 'i-test')
  end

  it 'does not put disk in the same AZ as a server if asked not to' do
    unique_name = SecureRandom.uuid
    disk_params = {
      display_name: "volume-#{unique_name}",
      display_description: '',
      name: "volume-#{unique_name}",
      description: '',
      size: 1,
    }
    server = double('server', id: 'i-test',
                              availability_zone: 'foobar-land')
    volume = double('volume', id: 'v-foobar')

    cloud_options = mock_cloud_options
    cloud_options['properties']['openstack']['ignore_server_availability_zone'] = true

    cloud = mock_cloud(cloud_options['properties']) do |fog|
      expect(fog.volume.volumes).to receive(:create)
        .with(disk_params).and_return(volume)
    end

    expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
    expect(cloud.openstack).to receive(:wait_resource).with(volume, :available)

    cloud.create_disk(1024, {}, 'i-test')
  end
end
