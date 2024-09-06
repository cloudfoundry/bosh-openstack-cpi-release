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

    it 'supports virtio-scsi properties' do
      properties = {
        'hw_disk_bus_model' => 'virtio-scsi',
        'hw_scsi_model' => 'virtio-scsi',
        'hw_disk_bus' => 'scsi',
      }

      expect(subject.normalize_image_properties(properties)).to include(
        :hw_disk_bus_model,
        :hw_scsi_model,
        :hw_disk_bus,
      )
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
