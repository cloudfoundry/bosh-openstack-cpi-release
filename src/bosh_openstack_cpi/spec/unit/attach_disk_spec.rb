require 'spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  let(:server_metadata) {[]}
  let(:server) { double('server', :id => 'i-test', :name => 'i-test', :flavor =>  { 'id' => 'f-test'}, :metadata => server_metadata) }
  let(:volume) { double('volume', :id => 'v-foobar') }
  let(:flavor) { double('flavor', :id => 'f-test', :ephemeral => 10, :swap => '') }
  let(:cloud) do
    mock_cloud(cloud_options['properties']) do |fog|
      expect(fog.compute.servers).to receive(:get).with('i-test').and_return(server)
      expect(fog.volume.volumes).to receive(:get).with('v-foobar').and_return(volume)
      expect(fog.compute.flavors).to receive(:find).and_return(flavor)
    end
  end
  let(:cloud_options) { mock_cloud_options }

  before(:each) do
    allow(server.metadata).to receive(:get).with(:registry_key).and_return(double('metadatum',{'value' => 'i-test'}))
    allow(Bosh::OpenStackCloud::TagManager).to receive(:tag)
    allow(volume).to receive(:save)
    @registry = mock_registry
  end

  it 'attaches an OpenStack volume to a server' do
    volume_attachments = []
    attachment = double('attachment', :device => '/dev/sdc')

    expect(server).to receive(:volume_attachments).and_return(volume_attachments)
    expect(server).to receive(:attach_volume).with(volume.id, '/dev/sdc').and_return(attachment)
    expect(cloud.openstack).to receive(:wait_resource).with(volume, :'in-use')

    old_settings = { 'foo' => 'bar'}
    new_settings = {
      'foo' => 'bar',
      'disks' => {
        'persistent' => {
          'v-foobar' => '/dev/sdc'
        }
      }
    }

    expect(@registry).to receive(:read_settings).with('i-test').and_return(old_settings)
    expect(@registry).to receive(:update_settings).with('i-test', new_settings)

    cloud.attach_disk('i-test', 'v-foobar')
  end

  context 'setting disk metadata' do
    let(:deployment_md) { double('metadatum', {'key' => 'deployment', 'value' => 'deployment-1'}) }
    let(:job_md) { double('metadatum', {'key' => 'job', 'value' => 'job-1'}) }
    let(:index_md) { double('metadatum', {'key' => 'index', 'value' => 'index-1'}) }
    let(:id_md) { double('metadatum', {'key' => 'id', 'value' => 'id-1'}) }
    let(:some_other_server_metadatum) { double('metadatum', {'key' => 'foo', 'value' => 'bar'}) }
    let(:server_metadata) { [deployment_md, job_md, index_md, id_md, some_other_server_metadatum] }

    before(:each) do
      allow(server).to receive(:volume_attachments).and_return([])
      allow(server).to receive(:attach_volume)
      allow(cloud.openstack).to receive(:wait_resource)
      allow(cloud).to receive(:update_agent_settings)
    end

    it 'copies the relevant server metadata to the disk' do
      cloud.attach_disk('i-test', 'v-foobar')

      expect(Bosh::OpenStackCloud::TagManager).to have_received(:tag).with(volume, deployment_md.key, deployment_md.value)
      expect(Bosh::OpenStackCloud::TagManager).to have_received(:tag).with(volume, job_md.key, job_md.value)
      expect(Bosh::OpenStackCloud::TagManager).to have_received(:tag).with(volume, index_md.key, index_md.value)
      expect(Bosh::OpenStackCloud::TagManager).to have_received(:tag).with(volume, id_md.key, id_md.value)
      expect(Bosh::OpenStackCloud::TagManager).to_not have_received(:tag).with(volume, some_other_server_metadatum.key, some_other_server_metadatum.value)
      expect(volume).to have_received(:save).exactly(4).times
    end
  end

  it 'picks available device name' do
    volume_attachments = [{'volumeId' => 'v-c', 'device' => '/dev/vdc'},
                          {'volumeId' => 'v-d', 'device' => '/dev/xvdd'}]
    attachment = double('attachment', :device => '/dev/sdd')

    expect(server).to receive(:volume_attachments).and_return(volume_attachments)
    expect(server).to receive(:attach_volume).with(volume.id, '/dev/sde').and_return(attachment)
    expect(cloud.openstack).to receive(:wait_resource).with(volume, :'in-use')

    old_settings = { 'foo' => 'bar'}
    new_settings = {
      'foo' => 'bar',
      'disks' => {
        'persistent' => {
          'v-foobar' => '/dev/sde'
        }
      }
    }

    expect(@registry).to receive(:read_settings).with('i-test').and_return(old_settings)
    expect(@registry).to receive(:update_settings).with('i-test', new_settings)

    cloud.attach_disk('i-test', 'v-foobar')
  end

  it 'raises an error when sdc..sdz are all reserved' do
    volume_attachments = ('c'..'z').inject([]) do |array, char|
      array << {'volumeId' => "v-#{char}", 'device' => "/dev/sd#{char}"}
      array
    end

    expect(server).to receive(:volume_attachments).and_return(volume_attachments)

    expect {
      cloud.attach_disk('i-test', 'v-foobar')
    }.to raise_error(Bosh::Clouds::CloudError, /too many disks attached/)
  end

  it 'bypasses the attaching process when volume is already attached to a server' do
    volume_attachments = [{'volumeId' => 'v-foobar', 'device' => '/dev/sdc'}]

    cloud = mock_cloud do |fog|
      expect(fog.compute.servers).to receive(:get).with('i-test').and_return(server)
      expect(fog.volume.volumes).to receive(:get).with('v-foobar').and_return(volume)
    end

    expect(server).to receive(:volume_attachments).and_return(volume_attachments)
    expect(volume).not_to receive(:attach)

    old_settings = { 'foo' => 'bar'}
    new_settings = {
        'foo' => 'bar',
        'disks' => {
            'persistent' => {
                'v-foobar' => '/dev/sdc'
            }
        }
    }

    expect(@registry).to receive(:read_settings).with('i-test').and_return(old_settings)
    expect(@registry).to receive(:update_settings).with('i-test', new_settings)

    cloud.attach_disk('i-test', 'v-foobar')
  end

  context 'first device name letter' do
    before do
      allow(server).to receive(:volume_attachments).and_return([])
      allow(cloud.openstack).to receive(:wait_resource)
      allow(cloud).to receive(:update_agent_settings)
    end
    subject(:attach_disk) { cloud.attach_disk('i-test', 'v-foobar') }

    let(:flavor) { double('flavor', :id => 'f-test', :ephemeral => 0, :swap => '') }

    context 'when there is no ephemeral, swap disk and config drive' do
      it 'return letter b' do
        expect(server).to receive(:attach_volume).with(volume.id, '/dev/sdb')
        attach_disk
      end
    end

    context 'when there is ephemeral disk' do
      let(:flavor) { double('flavor', :id => 'f-test', :ephemeral => 1024, :swap => '') }

      it 'return letter c' do
        expect(server).to receive(:attach_volume).with(volume.id, '/dev/sdc')
        attach_disk
      end
    end

    context 'when there is swap disk' do
      let(:flavor) { double('flavor', :id => 'f-test', :ephemeral => 0, :swap => 200) }

      it 'return letter c' do
        expect(server).to receive(:attach_volume).with(volume.id, '/dev/sdc')
        attach_disk
      end
    end

    context 'when config_drive is set as disk' do
      let(:cloud_options) do
        cloud_options = mock_cloud_options
        cloud_options['properties']['openstack']['config_drive'] = 'disk'
        cloud_options
      end

      it 'returns letter c' do
        expect(server).to receive(:attach_volume).with(volume.id, '/dev/sdc')
        attach_disk
      end
    end

    context 'when there is ephemeral and swap disk' do
      let(:flavor) { double('flavor', :id => 'f-test', :ephemeral => 1024, :swap => 200) }

      it 'returns letter d' do
        expect(server).to receive(:attach_volume).with(volume.id, '/dev/sdd')
        attach_disk
      end
    end

    context 'when there is ephemeral, swap disk and config drive is disk' do
      let(:flavor) { double('flavor', :id => 'f-test', :ephemeral => 1024, :swap => 200) }
      let(:cloud_options) do
        cloud_options = mock_cloud_options
        cloud_options['properties']['openstack']['config_drive'] = 'disk'
        cloud_options
      end

      it 'returns letter e' do
        expect(server).to receive(:attach_volume).with(volume.id, '/dev/sde')
        attach_disk
      end
    end

    context 'when server flavor is not found' do
      let(:flavor) { nil }

      it 'returns letter b' do
        expect(server).to receive(:attach_volume).with(volume.id, '/dev/sdb')
        attach_disk
      end
    end
  end
 end
