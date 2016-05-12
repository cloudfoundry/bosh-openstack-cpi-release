require 'spec_helper'
require 'cloud'
require 'logger'


describe Bosh::OpenStackCloud::Cloud do
  before do
    @domain            = LifecycleHelper.get_config(:domain, 'BOSH_OPENSTACK_DOMAIN')
    @auth_url          = LifecycleHelper.get_config(:auth_url, 'BOSH_OPENSTACK_AUTH_URL_V3')
    @username          = LifecycleHelper.get_config(:username, 'BOSH_OPENSTACK_USERNAME_V3')
    @api_key           = LifecycleHelper.get_config(:api_key, 'BOSH_OPENSTACK_API_KEY_V3')
    @project           = LifecycleHelper.get_config(:tenant, 'BOSH_OPENSTACK_PROJECT')
    @net_id            = LifecycleHelper.get_config(:net_id, 'BOSH_OPENSTACK_NET_ID')
    @manual_ip         = LifecycleHelper.get_config(:manual_ip, 'BOSH_OPENSTACK_MANUAL_IP')
    @disable_snapshots = LifecycleHelper.get_config(:disable_snapshots, 'BOSH_OPENSTACK_DISABLE_SNAPSHOTS', false)
    @default_key_name  = LifecycleHelper.get_config(:default_key_name, 'BOSH_OPENSTACK_DEFAULT_KEY_NAME', 'jenkins')
    @config_drive      = LifecycleHelper.get_config(:config_drive, 'BOSH_OPENSTACK_CONFIG_DRIVE', 'cdrom')
    @ignore_server_az  = LifecycleHelper.get_config(:ignore_server_az, 'BOSH_OPENSTACK_IGNORE_SERVER_AZ', 'false')
    @instance_type     = LifecycleHelper.get_config(:instance_type, 'BOSH_OPENSTACK_INSTANCE_TYPE', 'm1.small')
    @connect_timeout   = LifecycleHelper.get_config(:instance_type, 'BOSH_OPENSTACK_CONNECT_TIMEOUT', '120')
    @read_timeout      = LifecycleHelper.get_config(:instance_type, 'BOSH_OPENSTACK_READ_TIMEOUT', '120')
    @write_timeout     = LifecycleHelper.get_config(:instance_type, 'BOSH_OPENSTACK_WRITE_TIMEOUT', '120')
    ca_cert            = LifecycleHelper.get_config(:ca_cert, 'BOSH_OPENSTACK_CA_CERT', nil)
    @ca_cert_path = write_ssl_ca_file(ca_cert, logger) if ca_cert

    # some environments may not have this set, and it isn't strictly necessary so don't raise if it isn't set
    @region             = LifecycleHelper.get_config(:region, 'BOSH_OPENSTACK_REGION', nil)

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
        'connection_options' => {
          'connect_timeout' => @connect_timeout.to_i,
          'read_timeout' => @read_timeout.to_i,
          'write_timeout' => @write_timeout.to_i,
          'ssl_ca_file' => @ca_cert_path
        }
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

