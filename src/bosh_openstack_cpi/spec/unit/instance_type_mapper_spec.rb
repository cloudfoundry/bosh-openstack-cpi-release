require 'spec_helper'
require 'fog/compute/openstack/models/flavors'

describe Bosh::OpenStackCloud::InstanceTypeMapper do

  let(:mapper) { described_class.new }
  let(:flavors) do
    [
      instance_double(Fog::Compute::OpenStack::Flavor, id: '1', name: 'too_small',  vcpus: 1, ram: 2047, disk: 2, ephemeral: 49, disabled: false ),
      instance_double(Fog::Compute::OpenStack::Flavor, id: '2', name: 'too_big',    vcpus: 3, ram: 2049, disk: 4, ephemeral: 51, disabled: false ),
      instance_double(Fog::Compute::OpenStack::Flavor, id: '3', name: 'just_right', vcpus: 2, ram: 2048, disk: 3, ephemeral: 50, disabled: false ),
    ]
  end

  context 'when user default root disk properties (`boot_from_volume` set to false or unset)' do
    context 'when flavors have adequate vCPUs/RAM/root disk/ephemeral disk' do
      it 'returns the smallest flavor that meets the vCPU/RAM/root disk/ephemeral disk requirements' do
        requirements = {
          'ram' => 2048,
          'cpu' => 2,
          'ephemeral_disk_size' => 10 * 1024,
        }
        expect(mapper.map(requirements: requirements, flavors: flavors)['instance_type']).to eq('just_right')
      end
    end

    context 'when adequate flavors only differ by root disk/ephemeral disk sizes' do
      let(:flavors) do
        [
          instance_double(Fog::Compute::OpenStack::Flavor, id: '1', name: 'no_good',      vcpus: 1, ram: 2048, disk: 2, ephemeral: 10, disabled: false ),
          instance_double(Fog::Compute::OpenStack::Flavor, id: '2', name: 'good_but_big', vcpus: 1, ram: 2048, disk: 3, ephemeral: 13, disabled: false ),
          instance_double(Fog::Compute::OpenStack::Flavor, id: '3', name: 'good_yet_big', vcpus: 1, ram: 2048, disk: 4, ephemeral: 12, disabled: false ),
          instance_double(Fog::Compute::OpenStack::Flavor, id: '4', name: 'second_best',  vcpus: 1, ram: 2048, disk: 5, ephemeral: 10, disabled: false ),
          instance_double(Fog::Compute::OpenStack::Flavor, id: '5', name: 'best',         vcpus: 1, ram: 2048, disk: 4, ephemeral: 11, disabled: false ),
          instance_double(Fog::Compute::OpenStack::Flavor, id: '6', name: 'good_and_big', vcpus: 1, ram: 2048, disk: 5, ephemeral: 11, disabled: false ),
        ]
      end
      it 'returns the flavor that has the smallest total disk usage, and, in the event of a tie, the smallest root disk' do
        requirements = {
          'ram' => 2048,
          'cpu' => 1,
          'ephemeral_disk_size' => 10 * 1024,
        }
        expect(mapper.map(requirements: requirements, flavors: flavors)['instance_type']).to eq('best')
      end
    end

    context 'when no flavor meets the ephemeral requirements but the root disk is big enough to accommodate' do
      let(:flavors) do
        [
          instance_double(Fog::Compute::OpenStack::Flavor, id: '1', name: 'too_small',  vcpus: 1, ram: 2048, disk:  3, ephemeral:  9, disabled: false ),
          instance_double(Fog::Compute::OpenStack::Flavor, id: '2', name: 'too_small',  vcpus: 1, ram: 2048, disk: 12, ephemeral:  9, disabled: false ),
          instance_double(Fog::Compute::OpenStack::Flavor, id: '4', name: 'zero_ephem', vcpus: 2, ram: 2048, disk: 14, ephemeral:  0, disabled: false ),
          instance_double(Fog::Compute::OpenStack::Flavor, id: '3', name: 'big_root',   vcpus: 1, ram: 2048, disk: 13, ephemeral:  1, disabled: false ),
        ]
      end
      it 'returns the flavor that has the smallest big-enough root disk and has zero-size ephemeral disk' do
        requirements = {
          'ram' => 2048,
          'cpu' => 1,
          'ephemeral_disk_size' => 10 * 1024,
        }
        expect(mapper.map(requirements: requirements, flavors: flavors)['instance_type']).to eq('zero_ephem')
      end
    end

    context 'when flavors are inadequate' do
      let(:flavors) do
        [
          instance_double(Fog::Compute::OpenStack::Flavor, id: '1', name: 'way_too_small',    vcpus: 1, ram: 2048, disk: 10, ephemeral: 47, disabled: false ),
          instance_double(Fog::Compute::OpenStack::Flavor, id: '2', name: 'too_small',        vcpus: 1, ram: 2048, disk: 10, ephemeral: 48, disabled: false ),
          instance_double(Fog::Compute::OpenStack::Flavor, id: '3', name: 'barely_too_small', vcpus: 1, ram: 2048, disk: 10, ephemeral: 49, disabled: false ),
        ]
      end
      it 'raises an error' do
        requirements = {
          'ram' => 2048,
          'cpu' => 1,
          'ephemeral_disk_size' => 50 * 1024,
        }
        expect{mapper.map(requirements: requirements, flavors: flavors)['instance_type']}.to raise_error(/Unable to meet requested VM requirements/)
      end
    end
  end

  context 'when user sets root disk properties (`boot_from_volume` set to true)' do
    context 'when the flavors\' ephemeral disks\' sizes are too small' do
      let(:flavors) do
        [
          instance_double(Fog::Compute::OpenStack::Flavor, id: '1', name: 'too_small',      vcpus: 1, ram: 1024, disk: 0, ephemeral: 7, disabled: false ),
          instance_double(Fog::Compute::OpenStack::Flavor, id: '2', name: 'non_zero_ephem', vcpus: 2, ram: 2048, disk: 1, ephemeral: 8, disabled: false ),
          instance_double(Fog::Compute::OpenStack::Flavor, id: '3', name: 'zero_ephem',     vcpus: 3, ram: 4096, disk: 2, ephemeral: 0, disabled: false ),
        ]
      end
      it 'returns the smallest flavor that has a zero-size ephemeral disk, setting the root disk large enough for ephemeral + OS' do
        requirements = {
          'ram' => 2048,
          'cpu' => 2,
          'ephemeral_disk_size' => 10 * 1024,
        }
        cloud_props = mapper.map(requirements: requirements, flavors: flavors, boot_from_volume: true)
        expect(cloud_props['instance_type']).to eq('zero_ephem')
        expect(cloud_props).to have_key('root_disk')
        expect(cloud_props['root_disk']['size']).to eq(13)
      end
    end

    context 'when flavors are adequate (except root is too small)' do
      let(:flavors) do
        [
          instance_double(Fog::Compute::OpenStack::Flavor, id: '1', name: 'too_small',  vcpus: 1, ram: 1024, disk: 2, ephemeral:  9, disabled: false ),
          instance_double(Fog::Compute::OpenStack::Flavor, id: '2', name: 'just_right', vcpus: 2, ram: 2048, disk: 2, ephemeral: 10, disabled: false ),
          instance_double(Fog::Compute::OpenStack::Flavor, id: '3', name: 'too_big',    vcpus: 3, ram: 4096, disk: 2, ephemeral: 11, disabled: false ),
        ]
      end
      it 'returns the smallest flavor, setting the root_disk large enough for the OS' do
        requirements = {
          'ram' => 2048,
          'cpu' => 2,
          'ephemeral_disk_size' => 10 * 1024,
        }
        cloud_props = mapper.map(requirements: requirements, flavors: flavors, boot_from_volume: true)
        expect(cloud_props['instance_type']).to eq('just_right')
        expect(cloud_props).to have_key('root_disk')
        expect(cloud_props['root_disk']['size']).to eq(3) # 3 for OS
      end
    end

    context 'when flavors are inadequate' do
      let(:flavors) do
        [
          instance_double(Fog::Compute::OpenStack::Flavor, id: '1', name: 'way_too_small',    vcpus: 1, ram: 2045, disk: 0, ephemeral: 0, disabled: false ),
          instance_double(Fog::Compute::OpenStack::Flavor, id: '2', name: 'too_small',        vcpus: 1, ram: 2046, disk: 0, ephemeral: 0, disabled: false ),
          instance_double(Fog::Compute::OpenStack::Flavor, id: '3', name: 'barely_too_small', vcpus: 1, ram: 2047, disk: 0, ephemeral: 0, disabled: false ),
        ]
      end
      it 'raises an error' do
        requirements = {
          'ram' => 2048,
          'cpu' => 1,
          'ephemeral_disk_size' => 50 * 1024,
        }
        expect{mapper.map(requirements: requirements, flavors: flavors)['instance_type']}.to raise_error(/Unable to meet requested VM requirements/)
      end
    end
  end
end
