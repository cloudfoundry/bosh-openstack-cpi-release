require 'spec_helper'
require 'excon'

describe Bosh::OpenStackCloud::Cloud, 'resize_disk' do
  let(:volume) { double('volume', id: 'disk-id') }
  let(:cloud) {
    mock_cloud do |fog|
      expect(fog.volume.volumes).to receive(:get)
        .with('disk-id').and_return(volume)
    end
  }

  before do
    allow(volume).to receive(:size).and_return(2)
    allow(volume).to receive(:attachments).and_return([])
    allow(volume).to receive(:metadata).and_return(double('metadata'))
  end

  it 'uses the OpenStack endpoint to resize a disk' do
    allow(volume).to receive(:extend)
    allow(cloud.openstack).to receive(:wait_resource).with(volume, :available)

    return_value = cloud.resize_disk('disk-id', 4096)

    expect(return_value).to eq(nil)
    expect(volume).to have_received(:extend).with(4)
    expect(Bosh::Clouds::Config.logger).to have_received(:info).with('Resizing disk-id from 2 GiB to 4 GiB')
    expect(cloud.openstack).to have_received(:wait_resource).with(volume, :available)
    expect(Bosh::Clouds::Config.logger).to have_received(:info).with('Disk disk-id resized from 2 GiB to 4 GiB')
  end

  context 'when trying to resize to the same disk size' do
    it 'does not call extend on disk and writes to the log' do
      allow(volume).to receive(:extend)
      allow(Bosh::Clouds::Config.logger).to receive(:info)

      cloud.resize_disk('disk-id', 2048)

      expect(volume).to_not have_received(:extend).with(2)
      expect(Bosh::Clouds::Config.logger).to have_received(:info).with('Skipping resize of disk disk-id because current value 2 GiB is equal new value 2 GiB')
    end
  end

  context 'when trying to resize disk to a new size with an not even size in MiB' do
    it 'does not call extend on disk and writes to the log' do
      allow(volume).to receive(:extend)
      allow(Bosh::Clouds::Config.logger).to receive(:info)
      allow(cloud.openstack).to receive(:wait_resource).with(volume, :available)

      cloud.resize_disk('disk-id', 4097)

      expect(Bosh::Clouds::Config.logger).to have_received(:info).with('Resizing disk-id from 2 GiB to 5 GiB')
      expect(cloud.openstack).to have_received(:wait_resource).with(volume, :available)
      expect(volume).to have_received(:extend).with(5)
      expect(Bosh::Clouds::Config.logger).to have_received(:info).with('Disk disk-id resized from 2 GiB to 5 GiB')
    end
  end

  context 'when trying to resize a non existing disk' do
    let(:cloud) {
      mock_cloud do |fog|
        allow(fog.volume.volumes).to receive(:get)
          .with('non-existing-disk-id').and_return(nil)
      end
    }

    it 'fails' do
      expect {
        cloud.resize_disk('non-existing-disk-id', 1024)
      }.to raise_error(Bosh::Clouds::CloudError, 'Cannot resize volume because volume with non-existing-disk-id not found')
    end
  end

  context 'when trying to resize to a smaller disk' do
    it 'fails' do
      expect {
        cloud.resize_disk('disk-id', 1024)
      }.to raise_error(Bosh::Clouds::NotSupported, 'Cannot resize volume to a smaller size from 2 GiB to 1 GiB')
    end
  end

  context 'when volume is still attached' do
    before do
      allow(volume).to receive(:attachments).and_return([{}])
    end

    it 'fails' do
      expect {
        cloud.resize_disk('disk-id', 4096)
      }.to raise_error(Bosh::Clouds::CloudError, "Cannot resize volume 'disk-id' it still has 1 attachment(s)")
    end
  end

  context 'when extending volume fails on IaaS' do
    before do
      body
      response = Excon::Response.new(body: body)
      allow(volume).to receive(:extend).and_raise(Excon::Error::BadRequest.new('', '', response))
    end

    let(:body) { JSON.dump('badRequest' => { 'message' => 'some-message' }) }

    it 'raises an error' do
      expect {
        cloud.resize_disk('disk-id', 4096)
      }.to raise_error(Bosh::Clouds::CloudError, 'OpenStack API Bad Request (some-message). Check task debug log for details.')
    end
  end
end
