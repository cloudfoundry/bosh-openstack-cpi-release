require 'spec_helper'
require 'cloud'
require 'logger'


describe Bosh::OpenStackCloud::Cloud do
  before do
    @domain            = LifecycleHelper.get_config(:domain)
    @auth_url          = LifecycleHelper.get_config(:auth_url_v3)
    @username          = LifecycleHelper.get_config(:username_v3)
    @api_key           = LifecycleHelper.get_config(:api_key_v3)
    @project           = LifecycleHelper.get_config(:project)
    @net_id            = LifecycleHelper.get_config(:net_id)
    @manual_ip         = LifecycleHelper.get_config(:manual_ip)
    @disable_snapshots = LifecycleHelper.get_config(:disable_snapshots, false)
    @default_key_name  = LifecycleHelper.get_config(:default_key_name, 'jenkins')
    @config_drive      = LifecycleHelper.get_config(:config_drive, 'cdrom')
    @ignore_server_az  = LifecycleHelper.get_config(:ignore_server_az, 'false')
    @instance_type     = LifecycleHelper.get_config(:instance_type, 'm1.small')

    # some environments may not have this set, and it isn't strictly necessary so don't raise if it isn't set
    @region             = LifecycleHelper.get_config(:region, nil)

  end

  after(:each) { File.delete(@ca_cert_path) if @ca_cert_path }

  let(:boot_from_volume) { false }
  let(:config_drive) { nil }

  subject(:cpi) do
    described_class.new(
      'openstack' => {
        'auth_url' => @auth_url,
        'username' => @username,
        'api_key' => @api_key,
        'project' => @project,
        'domain' => @domain,
        'region' => @region,
        'endpoint_type' => 'publicURL',
        'default_key_name' => @default_key_name,
        'default_security_groups' => %w(default),
        'wait_resource_poll_interval' => 5,
        'boot_from_volume' => boot_from_volume,
        'config_drive' => config_drive,
        'ignore_server_availability_zone' => str_to_bool(@ignore_server_az),
        'connection_options' => connection_options(additional_connection_options(@logger))
      },
      'registry' => {
        'endpoint' => 'fake',
        'user' => 'fake',
        'password' => 'fake'
      }
    )
  end
  before do
    delegate = double('delegate', logger: logger, cpi_task_log: nil)
    Bosh::Clouds::Config.configure(delegate)
  end

  before { allow(Bosh::Clouds::Config).to receive(:logger).and_return(logger) }
  let(:logger) { Logger.new(STDERR) }

  describe 'Basic Keystone V3 support' do

    context 'with missing VM id' do

      it 'should return false' do
        logger.info("Checking VM existence")
        expect(cpi).to_not have_vm('non-existing-vm-id')
      end

    end

  end

  def str_to_bool(string)
    if string == 'true'
      true
    else
      false
    end
  end
end

