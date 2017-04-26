require "spec_helper"

describe Bosh::OpenStackCloud::TagManager do
  context '.tag_server' do
    let(:server) { double('server', :id => 'i-foobar') }
    let(:metadata) { double('metadata') }

    before do
      allow(server).to receive(:metadata).and_return(metadata)
      allow(metadata).to receive(:update)
    end

    it 'trims key and value length' do
      Bosh::OpenStackCloud::TagManager.tag_server(server, { 'x'*256 => 'y'*256 })

      expect(metadata).to have_received(:update).with({ 'x'*255 => 'y'*255 })
    end

    it 'sets multiple metadata tags' do
      Bosh::OpenStackCloud::TagManager.tag_server(server, { 'key1' => 'value1', 'key2' => 'value2' })

      expect(metadata).to have_received(:update).with({'key1' => 'value1', 'key2' => 'value2'})
    end

    it 'does nothing if key is nil' do
      Bosh::OpenStackCloud::TagManager.tag_server(server, { nil => 'value' })

      expect(server).to_not have_received(:metadata)
    end

    it 'does nothing if value is nil' do
      Bosh::OpenStackCloud::TagManager.tag_server(server, { 'key' => nil })

      expect(server).to_not have_received(:metadata)
    end
  end

  context '.tag_volume' do
    let(:volume) { double('volume') }

    before do
      allow(volume).to receive(:update_metadata)
    end

    it 'trims key and value length' do
      Bosh::OpenStackCloud::TagManager.tag_volume(volume, 'volume-id', { 'x'*256 => 'y'*256 })

      expect(volume).to have_received(:update_metadata).with('volume-id', { 'x'*255 => 'y'*255 })
    end

    it 'sets multiple metadata tags' do
      Bosh::OpenStackCloud::TagManager.tag_volume(volume, 'volume-id', { 'key1' => 'value1', 'key2' => 'value2' })

      expect(volume).to have_received(:update_metadata).with('volume-id', {'key1' => 'value1', 'key2' => 'value2'})
    end

    it 'does nothing if key is nil' do
      Bosh::OpenStackCloud::TagManager.tag_volume(volume, 'volume-id', { nil => 'value' })

      expect(volume).to_not have_received(:update_metadata)
    end

    it 'does nothing if value is nil' do
      Bosh::OpenStackCloud::TagManager.tag_volume(volume, 'volume-id', { 'key' => nil })

      expect(volume).to_not have_received(:update_metadata)
    end
  end
end
