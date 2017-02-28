require 'spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  let(:disk) { double('disk', :id => 'i-foobar', :metadata => double('metadata')) }
  let(:metadata) { { 'deployment' => 'deployment-x' } }

  context 'when disk exists' do
    before(:each) do
      @cloud = mock_cloud do |fog|
        allow(fog.volume.volumes).to receive(:get).with('i-foobar').and_return(disk)
      end
      allow(@cloud.volume).to receive(:update_metadata)
    end

    it 'should tag with given metadata' do
      @cloud.set_disk_metadata('i-foobar', metadata)
      expect(@cloud.volume).to have_received(:update_metadata).with('i-foobar', {'deployment' => 'deployment-x'})
    end

    it 'trims metadata keys and values' do
      expect(Bosh::OpenStackCloud::TagManager).to receive(:trim).with('deployment', 'deployment-x')
      @cloud.set_disk_metadata('i-foobar', metadata)
    end
  end

  context 'when disk does not exist' do
    before(:each) do
      @cloud = mock_cloud do |fog|
        allow(fog.volume.volumes).to receive(:get).with('i-foobar')
      end
    end

    it 'raises a cloud error' do
      expect {
        @cloud.set_disk_metadata('i-foobar', metadata)
      }.to raise_error(Bosh::Clouds::CloudError, "Disk `i-foobar' not found")
    end
  end
end
