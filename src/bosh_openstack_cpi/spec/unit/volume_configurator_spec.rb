require 'spec_helper'

describe Bosh::OpenStackCloud::VolumeConfigurator do
  let (:logger) do
    logger = double('logger')
    allow(logger).to receive(:debug)
    allow(logger).to receive(:error)
    logger
  end
  subject { Bosh::OpenStackCloud::VolumeConfigurator.new(logger) }
  describe 'select_boot_volume_size' do
    context 'when the flavor has no disk' do
      let (:flavor) { double('flavor', disk: 0, name: 'mock_flavor_without_disk') }

      context 'and resource pool contains root_disk.size > 1' do
        let (:resource_pool) { { 'root_disk' => { 'size' => 50 } } }

        it 'takes root disk size from resource pool as boot_volume size' do
          boot_volume_size = subject.select_boot_volume_size(flavor, resource_pool)
          expect(boot_volume_size).to be(50)
        end
      end

      context 'and resource pool contains root_disk.size = 1' do
        let (:resource_pool) { { 'root_disk' => { 'size' => 1 } } }

        it 'takes root disk size from resource pool as boot_volume size' do
          boot_volume_size = subject.select_boot_volume_size(flavor, resource_pool)
          expect(boot_volume_size).to be(1)
        end
      end

      context 'and resource pool contains root_disk.size < 1' do
        let (:resource_pool) { { 'root_disk' => { 'size' => 0 } } }

        it 'throw an error' do
          expect {
            subject.select_boot_volume_size(flavor, resource_pool)
          }.to raise_error(ArgumentError, 'Minimum root_disk size is 1 GiB')
        end
      end

      context 'root_disk not defined in resource pool' do
        let (:resource_pool) { {} }

        it 'takes the root disk size from the flavor' do
          expect {
            subject.select_boot_volume_size(flavor, resource_pool)
          }.to raise_error(Bosh::Clouds::CloudError, "Flavor 'mock_flavor_without_disk' has a root disk size of 0. Either pick a different flavor or define root_disk.size in your VM cloud_properties")
        end
      end

      context 'root_disk.size not defined in resource pool' do
        let (:resource_pool) { { 'root_disk' => {} } }

        it 'throw an error' do
          expect {
            subject.select_boot_volume_size(flavor, resource_pool)
          }.to raise_error(ArgumentError, 'Minimum root_disk size is 1 GiB')
        end
      end
    end

    context 'when the flavor has disk' do
      let (:flavor) { double('flavor', disk: 10) }

      context 'and resource pool contains root_disk.size > 1' do
        let (:resource_pool) { { 'root_disk' => { 'size' => 50 } } }

        it 'takes root disk size from resource pool as boot_volume size' do
          boot_volume_size = subject.select_boot_volume_size(flavor, resource_pool)
          expect(boot_volume_size).to be(50)
        end
      end

      context 'and resource pool contains root_disk.size = 1' do
        let (:resource_pool) { { 'root_disk' => { 'size' => 1 } } }

        it 'takes root disk size from resource pool as boot_volume size' do
          boot_volume_size = subject.select_boot_volume_size(flavor, resource_pool)
          expect(boot_volume_size).to be(1)
        end
      end

      context 'and resource pool contains root_disk.size < 1' do
        let (:resource_pool) { { 'root_disk' => { 'size' => 0 } } }

        it 'throw an error' do
          expect {
            subject.select_boot_volume_size(flavor, resource_pool)
          }.to raise_error(ArgumentError, 'Minimum root_disk size is 1 GiB')
        end
      end

      context 'root_disk not defined in resource pool' do
        let (:resource_pool) { {} }

        it 'takes the root disk size from the flavor' do
          boot_volume_size = subject.select_boot_volume_size(flavor, resource_pool)

          expect(boot_volume_size).to be(10)
        end
      end

      context 'root_disk.size not defined in resource pool' do
        let (:resource_pool) { { 'root_disk' => {} } }

        it 'throw an error' do
          expect {
            subject.select_boot_volume_size(flavor, resource_pool)
          }.to raise_error(ArgumentError, 'Minimum root_disk size is 1 GiB')
        end
      end
    end
  end

  describe 'boot_from_volume?' do
    context 'when global setting for boot_from_volume is false' do
      context 'when boot_from_volume set for vm type' do
        let (:resource_pool) { { 'boot_from_volume' => true } }

        it 'returns true' do
          boot_from_volume = subject.boot_from_volume?(false, resource_pool)

          expect(boot_from_volume).to be(true)
        end
      end

      context 'when boot_from_volume set to false for vm type' do
        let (:resource_pool) { { 'boot_from_volume' => false } }

        it 'returns false' do
          boot_from_volume = subject.boot_from_volume?(false, resource_pool)

          expect(boot_from_volume).to be(false)
        end
      end

      context 'when boot_from_volume is not set for vm type' do
        let (:resource_pool) { {} }

        it 'returns false' do
          boot_from_volume = subject.boot_from_volume?(false, resource_pool)

          expect(boot_from_volume).to be(false)
        end
      end
    end

    context 'when global setting for boot_from_volume is true' do
      context 'when boot_from_volume is not set for vm type' do
        let (:resource_pool) { {} }

        it 'it returns true' do
          boot_from_volume = subject.boot_from_volume?(true, resource_pool)

          expect(boot_from_volume).to be(true)
        end
      end

      context 'when boot_from_volume is set to false for vm type' do
        let (:resource_pool) { { 'boot_from_volume' => false } }

        it 'it returns true' do
          boot_from_volume = subject.boot_from_volume?(true, resource_pool)

          expect(boot_from_volume).to be(false)
        end
      end

      context 'when boot_from_volume is set to true for vm type' do
        let (:resource_pool) { { 'boot_from_volume' => true } }

        it 'it returns true' do
          boot_from_volume = subject.boot_from_volume?(true, resource_pool)

          expect(boot_from_volume).to be(true)
        end
      end
    end
  end
end
