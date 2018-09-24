require 'spec_helper'

describe Bosh::OpenStackCloud::AvailabilityZoneProvider do
  let(:foo_volume) { double('foo_volume') }
  let(:bar_volume) { double('bar_volume') }
  let(:volumes) { double('volumes') }
  let(:openstack) { instance_double(Bosh::OpenStackCloud::Openstack) }
  let(:compute) { double(Fog::OpenStack::Compute) }
  let(:volume) { double(Fog::Volume) }
  let(:az_provider) { Bosh::OpenStackCloud::AvailabilityZoneProvider.new(openstack, ignore_server_az) }

  before do
    allow(openstack).to receive(:compute).and_return(compute)
    allow(openstack).to receive(:volume).and_return(volume)
    allow(openstack).to receive(:with_openstack) { |&block| block.call }
    allow(bar_volume).to receive(:id).and_return('bar_id')
    allow(foo_volume).to receive(:id).and_return('foo_id')
    allow(foo_volume).to receive(:availability_zone).and_return('west_az')
    allow(volumes).to receive(:get).with('foo_id').and_return(foo_volume)
    allow(volumes).to receive(:get).with('bar_id').and_return(bar_volume)
    allow(volume).to receive(:volumes).and_return(volumes)
  end

  describe '.use_multiple_azs?' do
    let(:ignore_server_az) { true }
    let(:multiple_azs_cloud_properties) { { 'availability_zones' => %w[]} }
    let(:single_az_cloud_properties) { { 'availability_zone' => '' } }
    let(:invalid_cloud_properties) { { 'availability_zone' => '', 'availability_zones' => [] } }
    let(:empty_cloud_properties) { {} }

    it 'returns true if list is set' do
      expect(az_provider.use_multiple_azs?(multiple_azs_cloud_properties)).to be_truthy
    end

    it 'returns false if single_az is set' do
      expect(az_provider.use_multiple_azs?(single_az_cloud_properties)).to be_falsey
    end

    it 'should return false if neither is given' do
      expect(az_provider.use_multiple_azs?(empty_cloud_properties)).to be_falsey
    end

    it 'raises an exception if both are configured' do
      expect {
        az_provider.use_multiple_azs?(invalid_cloud_properties)
      }.to raise_error(Bosh::Clouds::CloudError, 'Invalid cloud_properties: only one property of "availability_zone" and "availability_zones" allowed.')
    end

    context 'when ignore_server is false' do
      let(:ignore_server_az) { false }
      let(:cloud_properties) { { } }

      it 'raises an error if az list is given and ignore_server_availability_zone is false' do
        expect {
          az_provider.use_multiple_azs?(multiple_azs_cloud_properties)
        }.to raise_error(Bosh::Clouds::CloudError, 'Cannot use multiple azs without openstack.ignore_server_availability_zone')
      end
    end

    # end
  end

  context 'when the server availability zone of the server must be the same as the disk' do
    let(:ignore_server_az) { false }

    context 'when the volume IDs are present' do
      context 'when az of volume is empty string' do
        before do
          allow(bar_volume).to receive(:availability_zone).and_return('')
        end

        it 'returns nil' do
          expect(az_provider.select(['bar_id'], nil)).to be_nil
        end
      end

      context 'when az of volume is nil' do
        before do
          allow(bar_volume).to receive(:availability_zone).and_return(nil)
        end

        it 'returns nil' do
          expect(az_provider.select(['bar_id'], nil)).to be_nil
        end
      end

      context 'when the volumes and resource pool are all from the same availability zone' do
        before do
          expect(bar_volume).to receive(:availability_zone).and_return('west_az')
        end

        it "should return the disk's availability zone" do
          selected_availability_zone = az_provider.select(%w[foo_id bar_id], 'west_az')
          expect(selected_availability_zone).to eq('west_az')
        end
      end

      context 'when the disks are from different AZs and no resource pool AZ is provided' do
        before do
          allow(bar_volume).to receive(:availability_zone).and_return('east_az')
        end

        it 'should raise an error' do
          expect {
            az_provider.select(%w[foo_id bar_id], nil)
          }.to raise_error Bosh::Clouds::CloudError, "can't use multiple availability zones: VM is created in default AZ, disk 'foo_id' is in AZ 'west_az', disk 'bar_id' is in AZ 'east_az'. Enable 'openstack.ignore_server_availability_zone' to allow VMs and disks to be in different AZs, or use the same AZ for both."
        end
      end

      context 'when the disks are from the same AZ and no resource pool AZ is provided' do
        before do
          expect(bar_volume).to receive(:availability_zone).and_return('west_az')
        end

        it 'should select the common disk AZ' do
          selected_availability_zone = az_provider.select(%w[foo_id bar_id], nil)
          expect(selected_availability_zone).to eq('west_az')
        end
      end

      context 'when there is a volume in a different AZ from other volumes or the resource pool AZ' do
        before do
          allow(bar_volume).to receive(:availability_zone).and_return('east_az')
        end

        it 'should raise an error' do
          expect {
            az_provider.select(%w[foo_id bar_id], 'west_az')
          }.to raise_error Bosh::Clouds::CloudError, "can't use multiple availability zones: VM is created in AZ 'west_az', disk 'foo_id' is in AZ 'west_az', disk 'bar_id' is in AZ 'east_az'. Enable 'openstack.ignore_server_availability_zone' to allow VMs and disks to be in different AZs, or use the same AZ for both."
        end
      end

      context 'when the disk AZs do not match the resource pool AZ' do
        before do
          allow(bar_volume).to receive(:availability_zone).and_return('west_az')
        end

        it 'should raise an error' do
          expect {
            az_provider.select(%w[foo_id bar_id], 'south_az')
          }.to raise_error Bosh::Clouds::CloudError, "can't use multiple availability zones: VM is created in AZ 'south_az', disk 'foo_id' is in AZ 'west_az', disk 'bar_id' is in AZ 'west_az'. Enable 'openstack.ignore_server_availability_zone' to allow VMs and disks to be in different AZs, or use the same AZ for both."
        end
      end

      context 'when all AZs provided are mismatched' do
        before do
          allow(bar_volume).to receive(:availability_zone).and_return('east_az')
        end

        it 'should raise an error' do
          expect {
            az_provider.select(%w[foo_id bar_id], 'south_az')
          }.to raise_error Bosh::Clouds::CloudError, "can't use multiple availability zones: VM is created in AZ 'south_az', disk 'foo_id' is in AZ 'west_az', disk 'bar_id' is in AZ 'east_az'. Enable 'openstack.ignore_server_availability_zone' to allow VMs and disks to be in different AZs, or use the same AZ for both."
        end
      end

      context 'when there are no disks IDs' do
        it 'should return the resource pool AZ value' do
          expect(az_provider.select([], nil)).to eq nil
          expect(az_provider.select([], 'north_az')).to eq('north_az')

          expect(az_provider.select(nil, 'north_az')).to eq('north_az')
        end
      end
    end

    context '.select_azs' do
      context 'when the server availability zone of the server can be different from the disk' do
        let(:availability_zones) { double }
        let(:cloud_properties) { { 'availability_zones' => availability_zones } }

        it 'should return the multiple availability zones' do
          allow(availability_zones).to receive(:shuffle).and_return(%w[multiple_id multiple_id2])
          selected_availability_zones = az_provider.select_azs(cloud_properties)

          expect(availability_zones).to have_received(:shuffle)
          expect(selected_availability_zones).to include('multiple_id', 'multiple_id2')
        end
      end
    end
  end
end
