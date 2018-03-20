describe Bosh::OpenStackCloud::HeavyStemcellCreator do
  subject { described_class }

  describe '#normalize_image_properties' do
    it 'rejects nil values' do
      properties = {
        'version' => nil,
      }

      expect(subject.normalize_image_properties(properties)).to_not have_key(:version)
    end

    it 'converts keys to symbols' do
      properties = {
        'version' => '123',
      }

      expect(subject.normalize_image_properties(properties)).to have_key(:version)
    end

    it 'maps hypervisor key to hypervisor_type' do
      properties = {
        'hypervisor' => 'kvm',
      }

      image_properties = subject.normalize_image_properties(properties)

      expect(image_properties[:hypervisor_type]).to eq('kvm')
      expect(image_properties).to_not have_key(:hypervisor)
    end
  end
end
