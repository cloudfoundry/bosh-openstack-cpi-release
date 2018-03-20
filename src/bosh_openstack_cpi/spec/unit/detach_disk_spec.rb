require 'spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  let(:server) { double('server', id: 'i-test', name: 'i-test', metadata: double('metadata')) }

  before(:each) do
    allow(server.metadata).to receive(:get).with(:registry_key).and_return(double('metadatum', 'value' => 'i-test'))
    @registry = mock_registry
  end

  it 'detaches an OpenStack volume from a server' do
    volume = double('volume', id: 'v-foobar')
    volume_attachments = [{ 'id' => 'a1', 'volumeId' => 'v-foobar' }, { 'id' => 'a2', 'volumeId' => 'v-barfoo' }]

    cloud = mock_cloud do |fog|
      expect(fog.compute.servers).to receive(:get).with('i-test').and_return(server)
      expect(fog.volume.volumes).to receive(:get).with('v-foobar').and_return(volume)
    end

    expect(server).to receive(:volume_attachments).and_return(volume_attachments)
    expect(server).to receive(:detach_volume).with(volume.id).and_return(true)
    expect(cloud.openstack).to receive(:wait_resource).with(volume, :available)

    old_settings = {
      'foo' => 'bar',
      'disks' => {
        'persistent' => {
          'v-foobar' => '/dev/vdc',
          'v-barfoo' => '/dev/vdd',
        },
      },
    }

    new_settings = {
      'foo' => 'bar',
      'disks' => {
        'persistent' => {
          'v-barfoo' => '/dev/vdd',
        },
      },
    }

    expect(@registry).to receive(:read_settings).with('i-test').and_return(old_settings)
    expect(@registry).to receive(:update_settings).with('i-test', new_settings)

    cloud.detach_disk('i-test', 'v-foobar')
  end

  it 'bypasses the detaching process when volume is not attached to a server' do
    volume = double('volume', id: 'v-barfoo')
    volume_attachments = [{ 'volumeId' => 'v-foobar' }]

    cloud = mock_cloud do |fog|
      expect(fog.compute.servers).to receive(:get).with('i-test').and_return(server)
      expect(fog.volume.volumes).to receive(:get).with('v-barfoo').and_return(volume)
    end

    expect(server).to receive(:volume_attachments).and_return(volume_attachments)
    expect(volume).not_to receive(:detach)

    old_settings = {
      'foo' => 'bar',
      'disks' => {
        'persistent' => {
          'v-foobar' => '/dev/vdc',
          'v-barfoo' => '/dev/vdd',
        },
      },
    }

    new_settings = {
      'foo' => 'bar',
      'disks' => {
        'persistent' => {
          'v-foobar' => '/dev/vdc',
        },
      },
    }

    expect(@registry).to receive(:read_settings).with('i-test').and_return(old_settings)
    expect(@registry).to receive(:update_settings).with('i-test', new_settings)

    cloud.detach_disk('i-test', 'v-barfoo')
  end

  it 'bypasses the detaching process when volume is missing' do
    cloud = mock_cloud do |fog|
      allow(fog.compute.servers).to receive(:get).with('i-test').and_return(server)
      allow(fog.volume.volumes).to receive(:get).with('non-exist-volume-id').and_return(nil)
    end

    old_settings = {
      'foo' => 'bar',
      'disks' => {
        'persistent' => {
          'non-exist-volume-id' => '/dev/vdc',
          'exist-volume-id' => '/dev/vdd',
        },
      },
    }

    new_settings = {
      'foo' => 'bar',
      'disks' => {
        'persistent' => {
          'exist-volume-id' => '/dev/vdd',
        },
      },
    }

    expect(@registry).to receive(:read_settings).with('i-test').and_return(old_settings)
    expect(@registry).to receive(:update_settings).with('i-test', new_settings)

    expect {
      cloud.detach_disk('i-test', 'non-exist-volume-id')
    }.to_not raise_error
  end
end
