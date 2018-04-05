require_relative './spec_helper'

describe Bosh::OpenStackCloud::ExconLoggingInstrumentor do
  include Bosh::OpenStackCloud::Helpers

  before(:all) do
    @config = IntegrationConfig.new
  end

  let(:logger) { instance_double('Logger') }

  before do
    delegate = double('delegate', logger: logger, cpi_task_log: nil)
    Bosh::Clouds::Config.configure(delegate)
    allow(Bosh::Clouds::Config).to receive(:logger).and_return(logger)
    allow(logger).to receive(:debug)
    allow(logger).to receive(:info)
  end

  let(:cpi) { @config.create_cpi(boot_from_volume: boot_from_volume) }

  let(:boot_from_volume) { false }

  it 'logs excon messages' do
    cpi.calculate_vm_cloud_properties(
      'ram' => 512,
      'cpu' => 1,
      'ephemeral_disk_size' => 2 * 1024,
    )

    expect(logger).to have_received(:debug).with(%r{excon.request GET https://.*:\d+/v\d\.\d/}).at_least(:once)
    expect(logger).to have_received(:debug).with(%r{excon.response HTTP/.*:\d+/v\d\.\d/}).at_least(:once)
  end

  it 'logs excon exceptions' do
    cpi.delete_disk('123')

    expect(logger).to have_received(:debug).with(%r{excon\.error HTTP/1\.1 404 Not Found /v2/.*/volumes/123 params: .*}).at_least(:once)
    expect(logger).not_to have_received(:debug).with(/excon\.error\.response/)
  end
end
