require_relative './spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  include Bosh::OpenStackCloud::Helpers

  before(:all) do
    @config = IntegrationConfig.new
  end

  let(:logger) { Logger.new(STDERR) }

  before do
    delegate = double('delegate', logger: logger, cpi_task_log: nil)
    Bosh::Clouds::Config.configure(delegate)
    allow(Bosh::Clouds::Config).to receive(:logger).and_return(logger)
  end

  let(:cpi_for_cloud_props) { @config.create_cpi(boot_from_volume: boot_from_volume) }

  let(:boot_from_volume) { false }

  it 'maps cloud agnostic VM properties to OpenStack-specific cloud_properties' do
    cloud_props = cpi_for_cloud_props.calculate_vm_cloud_properties(
      'ram' => 512,
      'cpu' => 1,
      'ephemeral_disk_size' => 2 * 1024,
    )

    expect(cloud_props).to include('instance_type')
    instance_type = cloud_props['instance_type']
    expect(instance_type).to_not be_nil

    flavor = cpi_for_cloud_props.compute.flavors.find { |f| f.name == instance_type }
    expect(flavor).to_not be_nil
    expect(flavor.ram).to be >= 512
    expect(flavor.vcpus).to be >= 1
    expect(flavor.disk).to be >= 2
  end

  context 'when boot_from_volume is true' do
    let(:boot_from_volume) { true }

    it 'sets custom root disk size if no flavor has enough ephemeral disk' do
      cloud_props = cpi_for_cloud_props.calculate_vm_cloud_properties(
        'ram' => 512,
        'cpu' => 1,
        'ephemeral_disk_size' => 10_000 * 1024, # assumes no flavor has 10TB disks
      )

      expect(cloud_props).to include('instance_type')
      instance_type = cloud_props['instance_type']
      expect(instance_type).to_not be_nil

      flavor = cpi_for_cloud_props.compute.flavors.find { |f| f.name == instance_type }
      expect(flavor).to_not be_nil
      expect(flavor.ram).to be >= 512
      expect(flavor.vcpus).to be >= 1

      custom_root_disk = cloud_props['root_disk']
      expect(custom_root_disk).to_not be_nil
      expect(custom_root_disk['size']).to be >= 10_000
    end
  end
end
