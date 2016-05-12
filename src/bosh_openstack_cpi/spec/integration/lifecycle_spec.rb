require 'spec_helper'
require 'tempfile'
require 'cloud'
require 'logger'
require 'ostruct'

describe Bosh::OpenStackCloud::Cloud do
  before(:all) do
    @logger              = Logger.new(STDERR)
    @auth_url            = LifecycleHelper.get_config(:auth_url, 'BOSH_OPENSTACK_AUTH_URL_V2')
    @username            = LifecycleHelper.get_config(:username, 'BOSH_OPENSTACK_USERNAME')
    @api_key             = LifecycleHelper.get_config(:api_key, 'BOSH_OPENSTACK_API_KEY')
    @tenant              = LifecycleHelper.get_config(:tenant, 'BOSH_OPENSTACK_TENANT')
    @stemcell_path       = LifecycleHelper.get_config(:stemcell_path, 'BOSH_OPENSTACK_STEMCELL_PATH')
    @net_id              = LifecycleHelper.get_config(:net_id, 'BOSH_OPENSTACK_NET_ID')
    @net_id_no_dhcp_1    = LifecycleHelper.get_config(:net_id, 'BOSH_OPENSTACK_NET_ID_NO_DHCP_1')
    @net_id_no_dhcp_2    = LifecycleHelper.get_config(:net_id, 'BOSH_OPENSTACK_NET_ID_NO_DHCP_2')
    @volume_type         = LifecycleHelper.get_config(:volume_type, 'BOSH_OPENSTACK_VOLUME_TYPE')
    @manual_ip           = LifecycleHelper.get_config(:manual_ip, 'BOSH_OPENSTACK_MANUAL_IP')
    @no_dhcp_manual_ip_1 = LifecycleHelper.get_config(:manual_ip, 'BOSH_OPENSTACK_NO_DHCP_MANUAL_IP_1')
    @no_dhcp_manual_ip_2 = LifecycleHelper.get_config(:manual_ip, 'BOSH_OPENSTACK_NO_DHCP_MANUAL_IP_2')
    @disable_snapshots   = LifecycleHelper.get_config(:disable_snapshots, 'BOSH_OPENSTACK_DISABLE_SNAPSHOTS', false)
    @default_key_name    = LifecycleHelper.get_config(:default_key_name, 'BOSH_OPENSTACK_DEFAULT_KEY_NAME', 'jenkins')
    @config_drive        = LifecycleHelper.get_config(:config_drive, 'BOSH_OPENSTACK_CONFIG_DRIVE', 'cdrom')
    @ignore_server_az    = LifecycleHelper.get_config(:ignore_server_az, 'BOSH_OPENSTACK_IGNORE_SERVER_AZ', 'false')
    @instance_type       = LifecycleHelper.get_config(:instance_type, 'BOSH_OPENSTACK_INSTANCE_TYPE', 'm1.small')
    @connect_timeout     = LifecycleHelper.get_config(:instance_type, 'BOSH_OPENSTACK_CONNECT_TIMEOUT', '120')
    @read_timeout        = LifecycleHelper.get_config(:instance_type, 'BOSH_OPENSTACK_READ_TIMEOUT', '120')
    @write_timeout       = LifecycleHelper.get_config(:instance_type, 'BOSH_OPENSTACK_WRITE_TIMEOUT', '120')
    ca_cert              = LifecycleHelper.get_config(:ca_cert, 'BOSH_OPENSTACK_CA_CERT', nil)
    @ca_cert_path        = write_ssl_ca_file(ca_cert, @logger) if ca_cert

    # some environments may not have this set, and it isn't strictly necessary so don't raise if it isn't set
    @region             = LifecycleHelper.get_config(:region, 'BOSH_OPENSTACK_REGION', nil)
    Bosh::Clouds::Config.configure(OpenStruct.new(:logger => @logger, :cpi_task_log => nil))
    @cpi_for_stemcell   = create_cpi(false, nil, false)
    @stemcell_id        = upload_stemcell
  end

  before { allow(Bosh::Clouds::Config).to receive(:logger).and_return(@logger) }

  after(:all) do
    begin
      @cpi_for_stemcell.delete_stemcell(@stemcell_id)
    ensure
      File.delete(@ca_cert_path) if @ca_cert_path
    end
  end

  let(:boot_from_volume) { false }
  let(:config_drive) { nil }
  let(:human_readable_vm_names) { false }

  subject(:cpi) do
    create_cpi(boot_from_volume, config_drive, human_readable_vm_names)
  end

  def create_cpi(boot_from_value, config_drive, human_readable_vm_names)
    described_class.new(
        'openstack' => {
            'auth_url' => @auth_url,
            'username' => @username,
            'api_key' => @api_key,
            'tenant' => @tenant,
            'region' => @region,
            'endpoint_type' => 'publicURL',
            'default_key_name' => @default_key_name,
            'default_security_groups' => %w(default),
            'wait_resource_poll_interval' => 5,
            'boot_from_volume' => boot_from_value,
            'config_drive' => config_drive,
            'ignore_server_availability_zone' => str_to_bool(@ignore_server_az),
            'human_readable_vm_names' => human_readable_vm_names,
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

  before { allow(Bosh::Cpi::RegistryClient).to receive(:new).and_return(double('registry').as_null_object) }

  describe 'dynamic network' do
    # even for dynamic networking we need to set the net_id as we may be in an environment
    # with multiple networks
    let(:network_spec) do
      {
        'default' => {
          'type' => 'dynamic',
          'cloud_properties' => {
            'net_id' => @net_id
          }
        }
      }
    end

    context 'without existing disks' do
      it 'exercises the vm lifecycle' do
        vm_lifecycle(@stemcell_id, network_spec, [])
      end
    end

    context 'with existing disks' do
      before { @existing_volume_id = cpi.create_disk(2048, {}) }
      after { cpi.delete_disk(@existing_volume_id) if @existing_volume_id }

      it 'exercises the vm lifecycle' do
        expect {
          vm_lifecycle(@stemcell_id, network_spec, [@existing_volume_id])
        }.to_not raise_error
      end
    end

    describe 'set_vm_metadata' do

      let(:human_readable_vm_names) { true }
      before { @human_readable_vm_name_id = create_vm(@stemcell_id, network_spec, []) }
      after { clean_up_vm(@human_readable_vm_name_id, network_spec) if @human_readable_vm_name_id }

      it 'sets the vm name according to the metadata' do
        vm = cpi.compute.servers.get(@human_readable_vm_name_id)
        expect(vm.name).to eq 'openstack_cpi_spec/instance_id'
      end

    end
  end

  describe 'manual network' do
    let(:network_spec) do
      {
        'default' => {
          'type' => 'manual',
          'ip' => @manual_ip,
          'cloud_properties' => {
            'net_id' => @net_id
          }
        }
      }
    end

    context 'without existing disks' do
      it 'exercises the vm lifecycle' do
        expect {
          vm_lifecycle(@stemcell_id, network_spec, [])
        }.to_not raise_error
      end
    end

    context 'with existing disks' do
      before { @existing_volume_id = cpi.create_disk(2048, {}) }
      after { cpi.delete_disk(@existing_volume_id) if @existing_volume_id }

      it 'exercises the vm lifecycle' do
        expect {
          vm_lifecycle(@stemcell_id, network_spec, [@existing_volume_id])
        }.to_not raise_error
      end
    end

    context 'with multiple networks and config_drive' do

      let(:multiple_network_spec) do
        {
          'network_1' => {
              'type' => 'manual',
              'ip' => @no_dhcp_manual_ip_1,
              'cloud_properties' => {
                  'net_id' => @net_id_no_dhcp_1
              }
          },
          'network_2' => {
              'type' => 'manual',
              'ip' => @no_dhcp_manual_ip_2,
              'cloud_properties' => {
                  'net_id' => @net_id_no_dhcp_2
              },
              'use_dhcp' => false
          }
        }
      end

      let(:config_drive) { 'cdrom' }

      after { clean_up_vm(@multiple_nics_vm_id, network_spec) if @multiple_nics_vm_id }

      it 'creates writes the mac addresses of the two networks to the registry' do
        registry = double('registry')
        registry_settings = nil
        allow(Bosh::Cpi::RegistryClient).to receive(:new).and_return(registry)
        allow(registry).to receive_messages(endpoint: nil, delete_settings:nil)
        allow(registry).to receive(:update_settings) do |_, settings|
          registry_settings = settings
        end

        @multiple_nics_vm_id = create_vm(@stemcell_id, multiple_network_spec, [])

        vm = cpi.compute.servers.get(@multiple_nics_vm_id)
        network_interfaces = vm.addresses.map { |_, network_interfaces| network_interfaces }.flatten
        network_interface_1 = network_interfaces.find(&where_ip_address_is(@no_dhcp_manual_ip_1))
        network_interface_2 = network_interfaces.find(&where_ip_address_is(@no_dhcp_manual_ip_2))

        expect(network_interface_1['OS-EXT-IPS-MAC:mac_addr']).to eq(registry_settings['networks']['network_1']['mac'])
        expect(network_interface_2['OS-EXT-IPS-MAC:mac_addr']).to eq(registry_settings['networks']['network_2']['mac'])

        ports = cpi.network.ports.all(:device_id => @multiple_nics_vm_id)
        clean_up_vm(@multiple_nics_vm_id, network_spec) if @multiple_nics_vm_id
        expect(ports.find{ |port| cpi.network.ports.get port.id }).to be_nil
      end

      def where_ip_address_is(ip)
        lambda { |network_interface| network_interface['addr'] == ip }
      end
    end
  end

  context 'when booting from volume' do
    let(:boot_from_volume) { true }

    let(:network_spec) do
      {
        'default' => {
          'type' => 'manual',
          'ip' => @manual_ip,
          'cloud_properties' => {
            'net_id' => @net_id
          }
        }
      }
    end

    it 'exercises the vm lifecycle' do
      expect {
        vm_lifecycle(@stemcell_id, network_spec, [])
      }.to_not raise_error
    end
  end

  context 'when using cloud_properties' do
    let(:cloud_properties) { { 'type' => @volume_type } }

    let(:network_spec) do
      {
        'default' => {
          'type' => 'dynamic',
          'cloud_properties' => {
            'net_id' => @net_id
          }
        }
      }
    end

    it 'exercises the vm lifecycle' do
      expect {
        vm_lifecycle(@stemcell_id, network_spec, [], cloud_properties)
      }.to_not raise_error
    end
  end

  context 'when using config drive as cdrom' do
    let(:config_drive) { @config_drive }

    let(:network_spec) do
      {
        'default' => {
          'type' => 'dynamic',
          'cloud_properties' => {
            'net_id' => @net_id
          }
        }
      }
    end

    it 'exercises the vm lifecycle' do
      expect {
        vm_lifecycle(@stemcell_id, network_spec, [])
      }.to_not raise_error
    end
  end

  context 'when vm creation fails' do
    let(:network_spec_that_fails) do
      {
        'default' => {
            'type' => 'manual',
            'ip' => @manual_ip,
            'cloud_properties' => {
                'net_id' => @net_id
            }
        },
        'vip' => {
          'type' => 'vip',
          'ip' => '255.255.255.255',
        }
      }
    end

    def no_active_vm_with_ip?(ip)
      cpi.compute.servers.none? do |s|
        s.private_ip_address == ip && [:active].include?(s.state.downcase.to_sym)
      end
    end

    it 'cleans up vm' do
      expect {
        create_vm(@stemcell_id, network_spec_that_fails, [])
      }.to raise_error Bosh::Clouds::VMCreationFailed, /Floating IP 255.255.255.255 not allocated/

      expect(no_active_vm_with_ip?(@manual_ip)).to be
    end

    it 'better error message for wrong net ID' do
      network_spec_with_wrong_net_id = {
          'default' => {
              'type' => 'dynamic',
              'cloud_properties' => {
                  'net_id' => '00000000-0000-0000-0000-000000000000'
              }
          }
      }
      expect {
        create_vm(@stemcell_id, network_spec_with_wrong_net_id, [])
      }.to raise_error Bosh::Clouds::VMCreationFailed, /'00000000-0000-0000-0000-000000000000'/
    end
  end

  context 'when detaching a non-existing disk' do
    # Detaching a non-existing disk from vm should NOT raise error
    let(:network_spec) do
      {
        'default' => {
          'type' => 'dynamic',
          'cloud_properties' => {
            'net_id' => @net_id
          }
        }
      }
    end

    it 'exercises the vm lifecycles' do
      vm_id = create_vm(@stemcell_id, network_spec, [])

      expect {
        @logger.info("Detaching disk vm_id=#{vm_id} disk_id=non-existing-disk")
        cpi.detach_disk(vm_id, "non-existing-disk")
      }.to_not raise_error

      clean_up_vm(vm_id, network_spec)
    end
  end

  def vm_lifecycle(stemcell_id, network_spec, disk_locality, cloud_properties = {})
    vm_id = create_vm(stemcell_id, network_spec, disk_locality)
    disk_id = create_disk(vm_id, cloud_properties)
    disk_snapshot_id = create_disk_snapshot(disk_id) unless @disable_snapshots
  rescue Exception => create_error
  ensure
    # create_error is in scope and possibly populated!
    funcs = [
      lambda { clean_up_disk(disk_id) },
      lambda { clean_up_vm(vm_id, network_spec) },
    ]
    funcs.unshift(lambda { clean_up_disk_snapshot(disk_snapshot_id) }) unless @disable_snapshots
    run_all_and_raise_any_errors(create_error, funcs)
  end

  def create_vm(stemcell_id, network_spec, disk_locality)
    @logger.info("Creating VM with stemcell_id=#{stemcell_id}")
    vm_id = cpi.create_vm(
      'agent-007',
      stemcell_id,
      { 'instance_type' => @instance_type },
      network_spec,
      disk_locality,
      { 'key' => 'value'}
    )
    expect(vm_id).to be

    @logger.info("Checking VM existence vm_id=#{vm_id}")
    expect(cpi).to have_vm(vm_id)

    @logger.info("Setting VM metadata vm_id=#{vm_id}")
    cpi.set_vm_metadata(vm_id, {
      'deployment' => 'deployment',
      'name' => 'openstack_cpi_spec/instance_id',
    })

    vm_id
  end

  def clean_up_vm(vm_id, network_spec)
    if vm_id
      @logger.info("Deleting VM vm_id=#{vm_id}")
      cpi.delete_vm(vm_id)

      @logger.info("Checking VM existence vm_id=#{vm_id}")
      expect(cpi).to_not have_vm(vm_id)

      if network_spec['default']['type'] == 'manual'
        # Wait for manual IP to be released by the infrastructure
        # We have seen Piston take a couple minutes to release an IP address
        sleep 120
      end
    else
      @logger.info('No VM to delete')
    end
  end

  def create_disk(vm_id, cloud_properties)
    @logger.info("Creating disk for VM vm_id=#{vm_id}")
    disk_id = cpi.create_disk(2048, cloud_properties, vm_id)
    expect(disk_id).to be

    @logger.info("Checking existence of disk vm_id=#{vm_id} disk_id=#{disk_id}")
    expect(cpi.has_disk?(disk_id)).to be(true)

    @logger.info("Attaching disk vm_id=#{vm_id} disk_id=#{disk_id}")
    cpi.attach_disk(vm_id, disk_id)

    @logger.info("Detaching disk vm_id=#{vm_id} disk_id=#{disk_id}")
    cpi.detach_disk(vm_id, disk_id)

    disk_id
  end

  def clean_up_disk(disk_id)
    if disk_id
      @logger.info("Deleting disk disk_id=#{disk_id}")
      cpi.delete_disk(disk_id)
    else
      @logger.info('No disk to delete')
    end
  end

  def create_disk_snapshot(disk_id)
    @logger.info("Creating disk snapshot disk_id=#{disk_id}")
    disk_snapshot_id = cpi.snapshot_disk(disk_id, {
      :deployment => 'deployment',
      :job => 'openstack_cpi_spec',
      :index => '0',
      :instance_id => 'instance',
      :agent_id => 'agent',
      :director_name => 'Director',
      :director_uuid => '6d06b0cc-2c08-43c5-95be-f1b2dd247e18',
    })
    expect(disk_snapshot_id).to be

    @logger.info("Created disk snapshot disk_snapshot_id=#{disk_snapshot_id}")
    disk_snapshot_id
  end

  def clean_up_disk_snapshot(disk_snapshot_id)
    if disk_snapshot_id
      @logger.info("Deleting disk snapshot disk_snapshot_id=#{disk_snapshot_id}")
      cpi.delete_snapshot(disk_snapshot_id)
    else
      @logger.info('No disk snapshot to delete')
    end
  end

  def run_all_and_raise_any_errors(existing_errors, funcs)
    exceptions = Array(existing_errors)
    funcs.each do |f|
      begin
        f.call
      rescue Exception => e
        exceptions << e
      end
    end
    # Prints all exceptions but raises original exception
    exceptions.each { |e| @logger.info("Failed with: #{e.inspect}\n#{e.backtrace.join("\n")}\n") }
    raise exceptions.first if exceptions.any?
  end

  def str_to_bool(string)
    if string == 'true'
      true
    else
      false
    end
  end

  def upload_stemcell
    stemcell_manifest = Psych.load_file(File.join(@stemcell_path, "stemcell.MF"))
    @cpi_for_stemcell.create_stemcell(File.join(@stemcell_path, "image"), stemcell_manifest["cloud_properties"])
  end
end
