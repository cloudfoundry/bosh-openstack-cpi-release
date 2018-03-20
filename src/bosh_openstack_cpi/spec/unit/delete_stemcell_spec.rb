require 'spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  it 'deletes stemcell' do
    image = double('image', id: 'i-foo', name: 'i-foo', properties: {})

    cloud = mock_glance_v2 do |glance|
      allow(glance.images).to receive(:find_by_id).with('i-foo').and_return(image)
    end

    expect(image).to receive(:destroy)

    cloud.delete_stemcell('i-foo')
  end

  describe 'with light stemcell' do
    it 'does no operation' do
      image = double('image', id: 'i-foo', name: 'i-foo', properties: {})

      cloud = mock_glance_v2 do |glance|
        allow(glance.images).to receive(:find_by_id).with('i-foo').and_return(image)
      end

      expect(image).not_to receive(:destroy)

      cloud.delete_stemcell('i-foo light')
    end
  end
end
