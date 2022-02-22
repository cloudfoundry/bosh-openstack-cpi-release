require_relative './spec_helper'

describe Bosh::OpenStackCloud::ExconLoggingInstrumentor do
  include Bosh::OpenStackCloud::Helpers

  before(:all) do
    @config = IntegrationConfig.new
  end

  let(:logger) { Bosh::Cpi::Logger.new(log) }
  let(:log) { StringIO.new('') }
  let(:request_id) { '1234' }
  let(:cpi) { @config.create_cpi(boot_from_volume:) }
  let(:boot_from_volume) { false }

  before do
    logger.set_request_id(request_id)
    allow(Bosh::Clouds::Config).to receive(:logger).and_return(logger)
  end

  it 'logs excon messages' do
    cpi.calculate_vm_cloud_properties(
      'ram' => 512,
      'cpu' => 1,
      'ephemeral_disk_size' => 2 * 1024,
    )

    expect(log.string).to match(%r{excon\.request GET https?://.*:\d+/v\d\.\d/})
    expect(log.string).to match(%r{excon\.response HTTP/.*:\d+/v\d\.\d/})
  end

  it 'logs excon exceptions' do
    cpi.delete_disk('123')

    expect(log.string).to match(%r{excon\.error HTTP/1\.1 404 Not Found /v2/.*/volumes/123 params: .*})
    expect(log.string).not_to include('excon.error.response')
  end

  it 'includes the request_id' do
    cpi.calculate_vm_cloud_properties(
      'ram' => 512,
      'cpu' => 1,
      'ephemeral_disk_size' => 2 * 1024,
    )

    expect(log.string).to include('[req_id 1234]')
  end
end
