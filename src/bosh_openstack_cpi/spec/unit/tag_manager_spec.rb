require 'spec_helper'

describe Bosh::OpenStackCloud::TagManager do
  describe '.tag_server' do
    let(:server) { double('server', id: 'i-foobar') }
    let(:metadata) { double('metadata') }

    before do
      allow(server).to receive(:metadata).and_return(metadata)
      allow(metadata).to receive(:update)
    end

    it 'sets multiple metadata tags' do
      Bosh::OpenStackCloud::TagManager.tag_server(server, 'key1' => 'value1', 'key2' => 'value2')

      expect(metadata).to have_received(:update).with('key1' => 'value1', 'key2' => 'value2')
    end

    it 'formats the tags' do
      Bosh::OpenStackCloud::TagManager.tag_server(server, 'key1' => 'value1', 2 => 2, 'key3' => nil)

      expect(metadata).to have_received(:update).with('key1' => 'value1', '2' => '2')
    end
  end

  describe '.tag_volume' do
    let(:volume) { double('volume') }

    before do
      allow(volume).to receive(:update_metadata)
    end

    it 'sets multiple metadata tags' do
      Bosh::OpenStackCloud::TagManager.tag_volume(volume, 'volume-id', 'key1' => 'value1', 'key2' => 'value2')

      expect(volume).to have_received(:update_metadata).with('volume-id', 'key1' => 'value1', 'key2' => 'value2')
    end

    it 'formats the tags' do
      Bosh::OpenStackCloud::TagManager.tag_volume(volume, 'volume-id', 'key1' => 'value1', 2 => 2, 'key3' => nil)

      expect(volume).to have_received(:update_metadata).with('volume-id', 'key1' => 'value1', '2' => '2')
    end
  end

  describe '.tag_snapshot' do
    let(:snapshot) { double('snapshot') }

    before do
      allow(snapshot).to receive(:update_metadata)
    end

    it 'sets multiple metadata tags' do
      Bosh::OpenStackCloud::TagManager.tag_snapshot(snapshot, 'key1' => 'value1', 'key2' => 'value2')

      expect(snapshot).to have_received(:update_metadata).with('key1' => 'value1', 'key2' => 'value2')
    end

    it 'formats the tags' do
      Bosh::OpenStackCloud::TagManager.tag_snapshot(snapshot, 'key1' => 'value1', 2 => 2, 'key3' => nil)

      expect(snapshot).to have_received(:update_metadata).with('key1' => 'value1', '2' => '2')
    end
  end

  describe '.format' do
    it 'trims key and value length' do
      formatted_tags = Bosh::OpenStackCloud::TagManager.format('x' * 256 => 'y' * 256)

      expect(formatted_tags).to eq('x' * 255 => 'y' * 255)
    end

    it 'converts all keys and value to strings' do
      formatted_tags = Bosh::OpenStackCloud::TagManager.format(1 => 5)

      expect(formatted_tags).to eq('1' => '5')
    end

    it 'does nothing if key is nil' do
      formatted_tags = Bosh::OpenStackCloud::TagManager.format(nil => 'value')

      expect(formatted_tags).to eq({})
    end

    it 'does nothing if value is nil' do
      formatted_tags = Bosh::OpenStackCloud::TagManager.format('key' => nil)

      expect(formatted_tags).to eq({})
    end
  end
end
