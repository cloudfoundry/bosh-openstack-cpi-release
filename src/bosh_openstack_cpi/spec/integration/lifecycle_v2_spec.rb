require_relative './spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  subject(:cpi) { @config.create_cpi }

  before(:all) do
    @config = IntegrationConfig.new(:v2)
  end

  let(:boot_from_volume) { false }
  let(:config_drive) { nil }
  let(:logger) { @config.logger }

  before do
    delegate = double('delegate', logger: logger, cpi_task_log: nil)
    Bosh::Clouds::Config.configure(delegate)
    allow(Bosh::Clouds::Config).to receive(:logger).and_return(logger)
  end

  describe 'Basic Keystone V2 support' do
    context 'with missing VM id' do
      it 'should return false' do
        logger.info('Checking VM existence')
        expect(cpi).to_not have_vm('non-existing-vm-id')
      end
    end
  end
end
