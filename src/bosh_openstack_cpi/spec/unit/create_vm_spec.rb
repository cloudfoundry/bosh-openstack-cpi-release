require 'spec_helper'
require 'excon'

describe Bosh::OpenStackCloud::Cloud, 'create_vm' do
  def agent_settings(unique_name, network_spec = dynamic_network_spec, ephemeral = '/dev/sdb')
    {
      'vm' => {
        'name' => "vm-#{unique_name}",
      },
      'agent_id' => 'agent-id',
      'networks' => { 'network_a' => network_spec },
      'disks' => {
        'system' => '/dev/sda',
        'ephemeral' => ephemeral,
        'persistent' => {},
      },
      'env' => {
        'test_env' => 'value',
      },
      'foo' => 'bar', # Agent env
      'baz' => 'zaz',
    }
  end

  def openstack_params(network_spec = { 'network_a' => dynamic_network_spec }, boot_from_volume = false)
    params = {
      name: "vm-#{unique_name}",
      image_ref: 'sc-id',
      flavor_ref: 'f-test',
      key_name: 'test_key',
      security_groups: configured_security_groups,
      os_scheduler_hints: scheduler_hints,
      nics: nics,
      config_drive: false,
      user_data: JSON.dump(user_data(unique_name, network_spec, nameserver, false)),
      availability_zone: 'foobar-1a',
    }

    if boot_from_volume
      params.delete(:image_ref)
      params[:block_device_mapping_v2] = [{
        uuid: 'sc-id',
        source_type: 'image',
        destination_type: 'volume',
        volume_size: 2,
        boot_index: '0',
        delete_on_termination: '1',
        device_name: '/dev/vda',
      }]
    end

    params
  end

  def user_data(unique_name, network_spec, nameserver = nil, openssh = false)
    user_data = {
      'server' => {
        'name' => "vm-#{unique_name}",
      },
    }
    user_data['openssh'] = { 'public_key' => 'public openssh key' } if openssh
    user_data['networks'] = network_spec
    user_data['dns'] = { 'nameserver' => [nameserver] } if nameserver
    user_data['registry'] = { 'endpoint' => 'http://registry:3333' }
    user_data
  end

  let(:unique_name) { SecureRandom.uuid }
  let(:server) { double('server', id: 'i-test', name: 'i-test') }
  let(:image) { double('image', id: 'sc-id', name: 'sc-id') }
  let(:flavor) { double('flavor', id: 'f-test', name: 'm1.tiny', ram: 1024, disk: 2, ephemeral: 2) }
  let(:key_pair) {
    double('key_pair', id: 'k-test', name: 'test_key',
                       fingerprint: '00:01:02:03:04', public_key: 'public openssh key')
  }
  let(:configured_security_groups) { %w[default] }
  let(:nameserver) { nil }
  let(:nics) { [] }
  let(:scheduler_hints) { nil }
  let(:options) { mock_cloud_options['properties'] }
  let(:environment) { { 'test_env' => 'value' } }
  let(:cpi_api_version) { 1 }
  let(:cloud) do
    mock_cloud(options, cpi_api_version) do |fog|
      allow(fog.image.images).to receive(:find_by_id).and_return(image)
      allow(fog.compute.servers).to receive(:create).and_return(server)
      allow(fog.compute.flavors).to receive(:find).and_return(flavor)
      allow(fog.compute.key_pairs).to receive(:find).and_return(key_pair)
		end
	end
	let(:network_configuration){
		{ 'network_a' => dynamic_network_spec }
	}

  before(:each) do
    @registry = mock_registry
    Bosh::Clouds::Config.configure(double('config', uuid: 'director-uuid'))
    allow(@registry).to receive(:delete_settings)
    allow(@registry).to receive(:update_settings)
    allow(cloud).to receive(:generate_unique_name).and_return(unique_name)
    allow(cloud.openstack).to receive(:wait_resource)
    allow(Bosh::OpenStackCloud::TagManager).to receive(:tag_server)
    allow(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:port_ids).and_return([])
  end

  it 'redacts user_data' do
    allow(Bosh::Clouds::Config.logger).to receive(:debug)

    cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)

    expect(Bosh::Clouds::Config.logger).to have_received(:debug).with(/Using boot params:.*"user_data"=>"<redacted>"/)
  end

  it "creates an OpenStack server and polls until it's ready" do
    vm_id = cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)
    expect(cloud.openstack).to have_received(:wait_resource).with(server, :active, :state)
    expect(vm_id).to eq('i-test')
  end

  describe 'multi-homed VMs' do
    let(:cloud) do
      cloud_options = mock_cloud_options['properties']
      cloud_options['openstack'].merge!(
        'config_drive' => 'cdrom',
        'use_dhcp' => false,
        'use_nova_networking' => false,
      )

      mock_cloud(cloud_options) do |openstack|
        allow(openstack.compute.servers).to receive(:create).and_return(server)
        allow(openstack.image.images).to receive(:find_by_id).and_return(image)
        allow(openstack.compute.flavors).to receive(:find).and_return(flavor)
        allow(openstack.compute.key_pairs).to receive(:find).and_return(key_pair)
        port_result_net = double('ports1', id: '117717c1-81cb-4ac4-96ab-99aaf1be9ca8', network_id: 'net', mac_address: 'AA:AA:AA:AA:AA:AA')
        ports = double('Fog::OpenStack::Network::Ports')
        allow(ports).to receive(:create).with(network_id: 'net', fixed_ips: [{ ip_address: '10.0.0.1' }], security_groups: ['default_sec_group_id']).and_return(port_result_net)
        allow(openstack.network).to receive(:ports).and_return(ports)
      end
    end
    let(:network_spec) { { 'network_a' => manual_network_spec(ip: '10.0.0.1') } }
    let(:expected_network_spec) { { 'network_a' => manual_network_spec(ip: '10.0.0.1', overwrites: { 'mac' => 'AA:AA:AA:AA:AA:AA', 'use_dhcp' => false }) } }
    let(:nics) { [{ 'net_id' => 'net', 'port_id' => '117717c1-81cb-4ac4-96ab-99aaf1be9ca8' }] }

    it 'creates an OpenStack server with config drive and mac addresses' do
      cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, network_spec, nil, environment)

      expect(cloud.compute.servers).to have_received(:create).with(openstack_params(expected_network_spec).merge(config_drive: true))
    end
  end

  context 'with nameserver' do
    let(:nameserver) { '1.2.3.4' }
    let(:network_spec) do
      network_spec = dynamic_network_spec
      network_spec['dns'] = [nameserver]
      network_spec
    end

    it 'passes dns servers in server user data when present' do
      cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => network_spec }, nil, environment)

      expect(cloud.openstack.compute.servers).to have_received(:create).with(openstack_params('network_a' => network_spec))
      expect(@registry).to have_received(:update_settings).with("vm-#{unique_name}", agent_settings(unique_name, network_spec))
    end
  end

  context 'with security groups' do
    let(:network_with_security_group) {
      ns = dynamic_network_spec
      ns['cloud_properties'] ||= {}
      ns['cloud_properties']['security_groups'] = %w[net-group-1 net-group-2]
      { 'network_a' => ns }
    }

    let(:resource_pool_with_security_group_spec) {
      rps = resource_pool_spec
      rps['security_groups'] = %w[pool-group-1 pool-group-2]
      rps
    }

    before(:each) do
      mock_sec_groups(cloud.network, openstack_security_groups)
    end

    context 'defined in both network and resource_pools spec' do
      let(:openstack_security_groups) {
        [
          double('net-group-1', id: 'net-group-1_id', name: 'net-group-1'),
          double('net-group-2', id: 'net-group-2_id', name: 'net-group-2'),
          double('pool-group-1', id: 'pool-group-1_id', name: 'pool-group-1'),
          double('pool-group-2', id: 'pool-group-2_id', name: 'pool-group-2'),
        ]
      }

      it 'uses the resource pool security groups to create vm' do
        cloud.create_vm('agent-id', 'sc-id', resource_pool_with_security_group_spec, network_with_security_group, nil, environment)

        expect(cloud.compute.servers).to have_received(:create).with(hash_including(security_groups: %w[pool-group-1 pool-group-2]))
      end
    end

    context 'defined in network spec' do
      let(:openstack_security_groups) {
        [
          double('net-group-1', id: 'net-group-1_id', name: 'net-group-1'),
          double('net-group-2', id: 'net-group-2_id', name: 'net-group-2'),
        ]
      }

      let(:configured_security_groups) { %w[net-group-1 net-group-2] }

      it 'creates an OpenStack server' do
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, network_with_security_group, nil, environment)

        expect(cloud.compute.servers).to have_received(:create).with(openstack_params(network_with_security_group))
        expect(@registry).to have_received(:update_settings).with("vm-#{unique_name}", agent_settings(unique_name, network_with_security_group['network_a']))
      end
    end

    context 'defined in resource_pools spec' do
      let(:openstack_security_groups) {
        [
          double('pool-group-1', id: 'pool-group-1_id', name: 'pool-group-1'),
          double('pool-group-2', id: 'pool-group-2_id', name: 'pool-group-2'),
        ]
      }

      let(:configured_security_groups) { %w[pool-group-1 pool-group-2] }

      let(:dynamic_network_without_security_group) do
        ns = dynamic_network_spec
        ns['cloud_properties'] = {}
        { 'network_a' => ns }
      end

      it 'creates an OpenStack server' do
        cloud.create_vm('agent-id', 'sc-id', resource_pool_with_security_group_spec, dynamic_network_without_security_group, nil, environment)

        expect(cloud.compute.servers).to have_received(:create).with(openstack_params(dynamic_network_without_security_group))
        expect(@registry).to have_received(:update_settings).with("vm-#{unique_name}", agent_settings(unique_name, dynamic_network_without_security_group['network_a']))
      end
    end
  end

  context 'with dynamic network' do
    context 'with nic' do
      let(:nics) do
        [
          { 'net_id' => 'foo' },
        ]
      end

      it 'creates an OpenStack server with nic for dynamic network' do
        network_spec = dynamic_network_spec
        network_spec['cloud_properties'] ||= {}
        network_spec['cloud_properties']['net_id'] = nics[0]['net_id']

        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => network_spec }, nil, environment)

        expect(cloud.compute.servers).to have_received(:create).with(openstack_params('network_a' => network_spec))
        expect(@registry).to have_received(:update_settings).with("vm-#{unique_name}", agent_settings(unique_name, network_spec))
      end
    end

    context 'when vrrp ip is configured' do
      let(:resource_pool_with_vrrp) {
        rps = resource_pool_spec
        rps['allowed_address_pairs'] = '10.0.0.10'
        rps
      }

      it 'raises an cloud error' do
        expect {
          cloud.create_vm('agent-id', 'sc-id', resource_pool_with_vrrp, { 'network' => dynamic_network_with_netid_spec }, nil, environment)
        }.to raise_error Bosh::Clouds::CloudError, "Network with id 'net' is a dynamic network. VRRP is not supported for dynamic networks"
      end
    end
  end

  context 'with manual network' do
    let(:several_manual_networks) do
      {
        'network_a' => manual_network_spec(ip: '10.0.0.1'),
        'network_b' => manual_network_spec(net_id: 'bar', ip: '10.0.0.2'),
      }
    end
    let(:manual_network) { { 'network_a' => manual_network_spec(ip: '10.0.0.1') } }

    let(:nics) { [{ 'net_id' => 'net', 'v4_fixed_ip' => '10.0.0.1' }, { 'net_id' => 'bar', 'v4_fixed_ip' => '10.0.0.2' }] }
    let(:configured_security_groups) { %w[default default] }
    let(:options) do
      cloud_options = mock_cloud_options
      cloud_options['properties']['openstack']['config_drive'] = 'cdrom'
      cloud_options['properties']['openstack']['use_dhcp'] = false
      cloud_options['properties']
    end

    it 'calls NetworkConfigurator#prepare and NetworkConfigurator#nics' do
      expect(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:new).with(anything, nil).and_call_original
      expect_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:prepare).with(anything)
      expect_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:nics).and_return(nics)

      cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, several_manual_networks, nil, environment)
    end

    context 'when vrrp ip is configured' do
      let(:resource_pool_with_vrrp) {
        rps = resource_pool_spec
        rps['allowed_address_pairs'] = '10.0.0.10'
        rps
      }

      it 'calls NetworkConfigurator#prepare and NetworkConfigurator#nics' do
        expect(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:new).with(anything, '10.0.0.10').and_call_original
        expect_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:prepare).with(anything)
        expect_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:nics).and_return(nics)

        cloud.create_vm('agent-id', 'sc-id', resource_pool_with_vrrp, several_manual_networks, nil, environment)
      end
    end

    context 'when vm_destroy fails' do
      before(:each) do
        allow(server).to receive(:destroy).and_raise 'BOOM!!!'
        allow_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:prepare)
        allow_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:cleanup)
      end

      it 'calls NetworkConfigurator#cleanup and fails with VMCreationFailed error' do
        allow_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:configure).and_raise 'BOOM configure!!!'

        expect {
          cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, manual_network, nil, environment)
        }.to raise_error Bosh::Clouds::VMCreationFailed, 'BOOM configure!!!'
      end
    end
  end

  context 'with scheduler hints' do
    let(:scheduler_hints) do
      { group: 'abcd-foo-bar' }
    end

    it 'creates an OpenStack server with scheduler hints' do
      allow_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:configure)

      cloud.create_vm('agent-id', 'sc-id', resource_pool_spec.merge('scheduler_hints' => scheduler_hints), combined_network_spec)

      expect(cloud.compute.servers).to have_received(:create).with(openstack_params(combined_network_spec))
    end
  end

  context 'when boot_from_volume is set' do
    let(:dynamic_network) { { 'network_a' => dynamic_network_spec } }

    context 'globally' do
      let(:options) do
        cloud_options = mock_cloud_options
        cloud_options['properties']['openstack']['boot_from_volume'] = true
        cloud_options['properties']
      end

      it 'creates an OpenStack server with a boot volume' do
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, dynamic_network, nil, environment)

        expect(cloud.compute.servers).to have_received(:create).with(openstack_params(dynamic_network, true))
      end
    end

    context 'for vm type' do
      let(:resource_pool_spec_with_boot_from_volume) { resource_pool_spec.merge('boot_from_volume' => true) }
      let(:options) do
        cloud_options = mock_cloud_options
        cloud_options['properties']['openstack']['boot_from_volume'] = false
        cloud_options['properties']
      end

      it 'creates an OpenStack server with a boot volume' do
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec_with_boot_from_volume, dynamic_network, nil, environment)

        expect(cloud.compute.servers).to have_received(:create).with(openstack_params(dynamic_network, true))
      end
    end

    context 'and a volume_type as well' do
      let(:options) do
        cloud_options = mock_cloud_options
        cloud_options['properties']['openstack']['boot_from_volume'] = true
        cloud_options['properties']['openstack']['boot_volume_cloud_properties'] = { 'type' => 'foo' }
        cloud_options['properties']
      end

      it 'creates an OpenStack server with a boot volume' do
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, dynamic_network, nil, environment)

        expect(cloud.compute.servers).to have_received(:create).with(openstack_params(dynamic_network, true))
      end
    end
  end

  context 'when config_drive option is set' do
    let(:options) do
      cloud_options = mock_cloud_options
      cloud_options['properties']['openstack']['config_drive'] = 'cdrom'
      cloud_options['properties']
    end

    it 'creates an OpenStack server with config drive' do
      cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)

      expect(cloud.compute.servers).to have_received(:create).with(openstack_params.merge(config_drive: true))
    end
  end

  context 'when OpenStack cannot create the server' do
    before do
      allow(server).to receive(:destroy)
    end

    context 'when OpenStack raises a Timeout error' do
      let(:socket_error) { Excon::Error::Timeout.new('read timeout reached') }

      it 'raises a Cloud error with vm information' do
        allow(cloud.compute.servers).to receive(:create).and_raise(socket_error)

        expect {
          cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)
        }.to raise_error(Bosh::Clouds::VMCreationFailed, /'vm-#{unique_name}'.*?\nOriginal message: read timeout reached/)
      end
    end

    context 'when OpenStack raises a Not Found error' do
      let(:networks) { double('networks') }
      let(:not_found_error) { Excon::Error::NotFound.new('not found: 814bc266-c6de-4fd0-a713-502da09edbe9') }

      before(:each) do
        allow(cloud.compute.servers).to receive(:create).and_raise(not_found_error)
        allow(cloud.network).to receive(:networks).and_return(networks)
      end

      it 'raises a VMCreationFailed error with subnet ID' do
        allow(networks).to receive(:get).and_return(nil)

        expect {
          cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_with_netid_spec }, nil, environment)
        }.to raise_error(Bosh::Clouds::VMCreationFailed, /'vm-#{unique_name}'.*?'net'/)
      end

      it 'raises a Not Found error with existing Net IDs' do
        allow_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:prepare)
        allow_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:cleanup)
        allow(networks).to receive(:get).and_return('some_network')
        network_with_different_net_id = { 'network_b' => manual_network_spec(net_id: 'some_other_id') }

        expect {
          cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, network_with_different_net_id, nil, environment)
        }.to raise_error(Excon::Error::NotFound, 'not found: 814bc266-c6de-4fd0-a713-502da09edbe9')
      end

      context 'when `openstack.network.networks.get` raises' do
        before(:each) do
          allow(networks).to receive(:get).and_raise('BOOM!!!')
        end

        it 'raises the original error' do
          allow_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:prepare)
          allow_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:cleanup)
          network_with_different_net_id = { 'network_b' => manual_network_spec(net_id: 'some_other_id') }

          expect {
            cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, network_with_different_net_id, nil, environment)
          }.to raise_error(Excon::Error::NotFound, 'not found: 814bc266-c6de-4fd0-a713-502da09edbe9')
        end
      end

      context 'when `use_nova_networking=true`' do
        let(:options) {
          mocked_options = mock_cloud_options(3)
          mocked_options['properties']['openstack']['use_nova_networking'] = true
          mocked_options['properties']
        }

        before(:each) do
          allow(cloud.compute.servers).to receive(:create).and_raise(not_found_error)
          security_groups = [double('default_sec_group', id: 'default_sec_group_id', name: 'default')]
          mock_sec_groups(cloud.compute, security_groups)
        end

        it 'raises a Not Found error with Network service not available' do
          expect {
            cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_with_netid_spec }, nil, environment)
          }.to raise_error(Excon::Error::NotFound)

          expect(cloud.network).to_not have_received(:networks)
        end
      end
    end

    context 'when OpenStack raises a BadRequest error' do
      let(:networks) { double('networks') }
      let(:bad_request_error) { Excon::Error::BadRequest.new('Message does not matter here') }

      before(:each) do
        allow(cloud.compute.servers).to receive(:create).and_raise(bad_request_error)
        allow(cloud.network).to receive(:networks).and_return(networks)
      end

      it 'raises a VMCreationFailed error with subnet ID' do
        allow(networks).to receive(:get).and_return(nil)

        expect {
          cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_with_netid_spec }, nil, environment)
        }.to raise_error(Bosh::Clouds::VMCreationFailed, /'vm-#{unique_name}'.*?'net'/)
      end
    end

    context 'with a CloudError' do
      it 'destroys the server successfully' do
        allow(cloud.openstack).to receive(:wait_resource).with(server, :active, :state).and_raise(Bosh::Clouds::CloudError)
        expect(cloud.openstack).to receive(:wait_resource).with(server, %i[terminated deleted], :state, true)

        expect {
          cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)
        }.to raise_error(Bosh::Clouds::VMCreationFailed)
      end
    end

    context 'with a StandardError' do
      it 'destroys the server successfully' do
        allow(cloud.openstack).to receive(:wait_resource).with(server, :active, :state).and_raise(StandardError)
        expect(cloud.openstack).to receive(:wait_resource).with(server, %i[terminated deleted], :state, true)

        expect {
          cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)
        }.to raise_error(Bosh::Clouds::VMCreationFailed)
      end
    end

    it 'raises a VMCreationFailed error and logs correct failure message when failed to destroy the server' do
      allow(server).to receive(:destroy)
      allow(cloud.openstack).to receive(:wait_resource).with(server, :active, :state).and_raise(Bosh::Clouds::CloudError)
      allow(cloud.openstack).to receive(:wait_resource).with(server, %i[terminated deleted], :state, true).and_raise(Bosh::Clouds::CloudError)

      expect {
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)
      }.to raise_error(Bosh::Clouds::VMCreationFailed)

      expect(Bosh::Clouds::Config.logger).to have_received(:warn).with('Failed to create server: Bosh::Clouds::CloudError')
      expect(Bosh::Clouds::Config.logger).to have_received(:warn).with(/Failed to destroy server:.*/)
    end
  end

  context 'when fail to register an OpenStack server after the server is created' do
    before(:each) { allow(server).to receive(:destroy) }

    it 'destroys the server successfully and raises a non-retryable Error when CloudError happens' do
      allow(@registry).to receive(:update_settings).and_raise(Bosh::Clouds::CloudError)

      expect {
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)
      }.to raise_error { |error|
             expect(error).to be_a(Bosh::Clouds::VMCreationFailed)
             expect(error.ok_to_retry).to eq(false)
           }
      expect(cloud.openstack).to have_received(:wait_resource).with(server, %i[terminated deleted], :state, true)
    end

    it 'destroys the server successfully and raises a non-retryable Error when StandardError happens' do
      allow(@registry).to receive(:update_settings).and_raise(StandardError)

      expect {
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)
      }.to raise_error { |error|
             expect(error).to be_a(Bosh::Clouds::VMCreationFailed)
             expect(error.ok_to_retry).to eq(false)
           }
      expect(cloud.openstack).to have_received(:wait_resource).with(server, %i[terminated deleted], :state, true)
    end

    it 'logs correct failure message when failed to destroy the server' do
      allow(@registry).to receive(:update_settings).and_raise(Bosh::Clouds::CloudError)
      allow(cloud.openstack).to receive(:wait_resource).with(server, %i[terminated deleted], :state, true).and_raise(Bosh::Clouds::CloudError)

      expect {
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)
      }.to raise_error(Bosh::Clouds::VMCreationFailed)
      expect(Bosh::Clouds::Config.logger).to have_received(:warn).with('Failed to register server: Bosh::Clouds::CloudError')
      expect(Bosh::Clouds::Config.logger).to have_received(:warn).with(/Failed to destroy server:.*/)
    end
  end

  context "when security group doesn't exist" do
    let(:openstack_security_groups) { [double('foo-sec-group', id: 'foo-sec-group-id', name: 'foo')] }

    it 'raises an error' do
      mock_sec_groups(cloud.network, openstack_security_groups)

      expect {
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)
      }.to raise_error(Bosh::Clouds::CloudError, "Security group `default' not found")
    end
  end

  it "raises an error when flavor doesn't have enough ephemeral disk capacity" do
    flavor = double('flavor', id: 'f-test', name: 'm1.tiny', ram: 1024, ephemeral: 1)
    allow(cloud.compute.flavors).to receive(:find).and_return(flavor)

    expect {
      cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)
    }.to raise_error(Bosh::Clouds::CloudError, "Flavor `m1.tiny' should have at least 2Gb of ephemeral disk")
  end

  context 'when use_dhcp is set to false' do
    let(:options) do
      cloud_options = mock_cloud_options
      cloud_options['properties']['openstack']['use_dhcp'] = false
      cloud_options['properties']
    end

    it 'updates network settings to include use_dhcp as false' do
      expected_network_spec = dynamic_network_spec
      expected_network_spec['use_dhcp'] = false
      expected_openstack_params = openstack_params('network_a' => expected_network_spec)

      cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)
      expect(cloud.compute.servers).to have_received(:create).with(expected_openstack_params)
    end
  end

  describe 'key_name configuration' do
    let(:resource_pool_spec_no_key) do
      {
        'availability_zone' => 'foobar-1a',
        'instance_type' => 'm1.tiny',
      }
    end

    context 'when key_name is only defined in resource pool' do
      it 'takes the key_name from resource pool' do
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)

        expect(cloud.compute.servers).to have_received(:create).with(openstack_params)
      end
    end

    context 'when default_key_name is only defined in CPI cloud properties' do
      let(:options) do
        cloud_options_with_default_key_name = mock_cloud_options['properties']
        cloud_options_with_default_key_name['openstack']['default_key_name'] = 'default_key_name'
        cloud_options_with_default_key_name
      end

      before(:each) do
        allow(cloud).to receive(:validate_key_exists)
      end

      it 'takes the key_name from CPI cloud properties' do
        expected_openstack_params = openstack_params
        expected_openstack_params[:key_name] = 'default_key_name'

        expect_any_instance_of(Bosh::OpenStackCloud::VmFactory).to receive(:validate_key_exists).with(options['openstack']['default_key_name'])

        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec_no_key, { 'network_a' => dynamic_network_spec }, nil, environment)

        expect(cloud.compute.servers).to have_received(:create).with(expected_openstack_params)
      end
    end

    context 'when default_key_name is defined in CPI cloud properties and key_name in resource pool' do
      let(:options) do
        cloud_options_with_default_key_name = mock_cloud_options['properties']
        cloud_options_with_default_key_name['openstack']['default_key_name'] = 'default_key_name'
        cloud_options_with_default_key_name
      end

      before(:each) do
        allow(cloud).to receive(:validate_key_exists)
      end

      it 'takes the key_name from resource pool' do
        expect_any_instance_of(Bosh::OpenStackCloud::VmFactory).to receive(:validate_key_exists).with('test_key')
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)
      end
    end

    context 'when no key_name is defined' do
      it 'raises cloud error' do
        allow(cloud.compute).to receive(:key_pairs).and_return([key_pair])

        expect {
          cloud.create_vm('agent-id', 'sc-id', resource_pool_spec_no_key, { 'network_a' => dynamic_network_spec }, nil, environment)
        }.to raise_error(Bosh::Clouds::CloudError, "Key-pair `' not found")
      end
    end
  end

  describe 'use "vm-<uuid>" as registry key' do
    context 'when "human_readable_vm_names" is enabled' do
      let(:options) do
        options = mock_cloud_options['properties']
        options['openstack']['human_readable_vm_names'] = true
        options
      end

      it 'logs human_readable_vm_names enabled' do
        # Bosh.retryable requires us to return a non-nil value from debug
        allow(Bosh::Clouds::Config.logger).to receive(:debug).and_return('logged')

        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)

        expect(Bosh::Clouds::Config.logger).to have_received(:debug).with("'human_readable_vm_names' enabled")
        expect(Bosh::Clouds::Config.logger).to have_received(:debug).with("Tagged VM 'i-test' with tags '{:registry_key=>\"vm-#{unique_name}\"}")
      end
    end

    context 'when "human_readable_vm_names" is disabled' do
      let(:options) do
        options = mock_cloud_options['properties']
      end

      it 'does not tag server with registry tag' do
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)

        expect(Bosh::OpenStackCloud::TagManager).to_not have_received(:tag_server).with(server, registry_key: "vm-#{unique_name}")
      end

      it 'logs human_readable_vm_names disabled' do
        # Bosh.retryable requires us to return a non-nil value from debug
        allow(Bosh::Clouds::Config.logger).to receive(:debug).and_return('logged')

        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)

        expect(Bosh::Clouds::Config.logger).to have_received(:debug).with("'human_readable_vm_names' disabled")
      end
    end
  end

  describe 'with light stemcell' do
    it 'creates the vm with the image id of the heavy stemcell' do
      cloud.create_vm('agent-id', 'sc-id light', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)

      expect(cloud.compute.servers).to have_received(:create).with(openstack_params)
      expect(@registry).to have_received(:update_settings).with("vm-#{unique_name}", agent_settings(unique_name))
    end
  end

  describe 'with loadbalancer pool' do
    let(:resource_pool_spec_with_lbaas_pools) do
      resource_pool_spec.merge(
        'loadbalancer_pools' => [
          { 'name' => 'my-pool-1', 'port' => 443 },
          { 'name' => 'my-pool-2', 'port' => 8080 },
        ],
      )
    end

    it 'creates as many loadbalancers as are listed in the manifest' do
      network_spec = { 'network_a' => dynamic_network_spec }
      pool_membership = Bosh::OpenStackCloud::LoadbalancerConfigurator::LoadbalancerPoolMembership.new('name', 'port', 'pool_id', 'membership_id')

      expect_any_instance_of(Bosh::OpenStackCloud::LoadbalancerConfigurator)
        .to receive(:add_vm_to_pool)
        .with(server, network_spec, 'name' => 'my-pool-1', 'port' => 443)
        .and_return(pool_membership)
      expect_any_instance_of(Bosh::OpenStackCloud::LoadbalancerConfigurator)
        .to receive(:add_vm_to_pool)
        .with(server, network_spec, 'name' => 'my-pool-2', 'port' => 8080)
        .and_return(pool_membership)

      cloud.create_vm('agent-id', 'sc-id light', resource_pool_spec_with_lbaas_pools, network_spec, nil, environment)
    end
  end

  describe 'setting VM metadata' do
    context 'when human_readable_vm_names are enabled' do
      let(:options) do
        options = mock_cloud_options['properties']
        options['openstack']['human_readable_vm_names'] = true
        options
      end

      it 'tags registry_key with "vm-<uuid>"' do
        allow(Bosh::OpenStackCloud::TagManager).to receive(:tag_server)

        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)

        expect(Bosh::OpenStackCloud::TagManager).to have_received(:tag_server).with(server, registry_key: "vm-#{unique_name}")
      end

      it 'raises an exception, if tagging fails' do
        allow(Bosh::OpenStackCloud::TagManager).to receive(:tag_server).and_raise(StandardError)

        expect(server).to receive(:destroy)
        expect {
          cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)
        }.to raise_error(Bosh::Clouds::CloudError)
      end
    end

    context 'when loadbalancer_pools are present' do
      let(:resource_pool_spec_with_lbaas_pools) do
        resource_pool_spec.merge(
          'loadbalancer_pools' => [
            { 'name' => 'my-pool-1', 'port' => 443 },
            { 'name' => 'my-pool-2', 'port' => 8080 },
          ],
        )
      end

      let(:loadbalancer_configurator) { instance_double(Bosh::OpenStackCloud::LoadbalancerConfigurator) }

      before(:each) do
        allow(Bosh::OpenStackCloud::LoadbalancerConfigurator).to receive(:new).and_return(loadbalancer_configurator)
        allow(loadbalancer_configurator).to receive(:create_pool_memberships).and_return(
          'lbaas_pool_1' => 'pool_id/membership_id',
          'lbaas_pool_2' => 'pool_id/membership_id',
        )
        allow(Bosh::OpenStackCloud::TagManager).to receive(:tag_server)
      end

      it 'tags the vm with the lbaas pool and membership' do
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec_with_lbaas_pools, { 'network_a' => dynamic_network_spec }, nil, environment)

        expect(Bosh::OpenStackCloud::TagManager).to have_received(:tag_server).with(server,
                                                                                    'lbaas_pool_1' => 'pool_id/membership_id',
                                                                                    'lbaas_pool_2' => 'pool_id/membership_id')
      end

      context 'when tagging fails' do
        it 'cleans up the membership and raises an exception' do
          allow(Bosh::OpenStackCloud::TagManager).to receive(:tag_server).and_raise(StandardError)
          allow(loadbalancer_configurator).to receive(:cleanup_memberships)
          allow(server).to receive(:destroy)

          expect {
            cloud.create_vm('agent-id', 'sc-id', resource_pool_spec_with_lbaas_pools, { 'network_a' => dynamic_network_spec }, nil, environment)
          }.to raise_error(Bosh::Clouds::CloudError)
          expect(server).to have_received(:destroy)
          expect(loadbalancer_configurator).to have_received(:cleanup_memberships).with(
            'lbaas_pool_1' => 'pool_id/membership_id',
            'lbaas_pool_2' => 'pool_id/membership_id',
          )
        end
      end
    end
  end

  describe 'when multiple azs are configured' do
    let(:options) do
      options = mock_cloud_options['properties']
      options['openstack']['ignore_server_availability_zone'] = true
      options
    end

    let(:azs) { ['az-1', 'az-2'] }
    let(:resource_pool_spec) do
      {
        'key_name' => 'test_key',
        'availability_zones' => azs,
        'instance_type' => 'm1.tiny',
      }
    end

    context 'dynamic network' do
      it 'creates the vm in one of the configured azs' do
        expect(cloud.compute.servers).to receive(:create).with(
          include(availability_zone: 'az-1').or(include(availability_zone: 'az-2')),
        )

        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)
      end

      it 'iterates over the azs till it can create a vm in one of the configured azs' do
        allow_any_instance_of(Bosh::OpenStackCloud::AvailabilityZoneProvider).to receive(:select_azs).and_return(azs)
        allow(cloud.compute.servers)
          .to receive(:create)
          .with(include(availability_zone: 'az-1'))
          .and_raise Bosh::Clouds::CloudError.new('Example exception from infrastructure')

        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)

        expect(cloud.compute.servers).to have_received(:create).with(include(availability_zone: 'az-1'))
        expect(cloud.compute.servers).to have_received(:create).with(include(availability_zone: 'az-2'))
      end

      context 'last try fails' do
        let(:err) { Bosh::Clouds::CloudError.new('Example exception from infrastructure') }
        before { allow(cloud.compute.servers).to receive(:create).and_raise err }

        it 'raises an error if last try fails' do
          expect {
            cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, { 'network_a' => dynamic_network_spec }, nil, environment)
          }.to raise_error(Bosh::Clouds::CloudError)
          expect(cloud.compute.servers).to have_received(:create).with(include(availability_zone: 'az-1'))
          expect(cloud.compute.servers).to have_received(:create).with(include(availability_zone: 'az-2'))
        end
      end
    end
  end


  context 'when requested cpi api version is 1' do
		it 'sets networks in user data' do
			cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, network_configuration, nil, environment)

			expect(cloud.compute.servers).to have_received(:create).with(hash_including(user_data: /\"networks\":{\"network_a\":{\"type\":\"dynamic\",\"cloud_properties\":{\"security_groups\":\[\"default\"\]},\"use_dhcp\":true}}/ ))
		end

		context 'when stemcell API v1' do
			it 'does not set agent_id in user data' do
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, network_configuration, nil, environment)

        expect(cloud.compute.servers).to have_received(:create)
        expect(cloud.compute.servers).not_to have_received(:create).with(hash_including(user_data: /\"agent_id\":/ ))
      end

      it 'does not set env in user data' do
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, network_configuration, nil, environment)

        expect(cloud.compute.servers).to have_received(:create)
        expect(cloud.compute.servers).not_to have_received(:create).with(hash_including(user_data: /\"env\":/ ))
      end
    end

    context 'when stemcell API v2' do
      let(:options) do
        options = mock_cloud_options['properties']
        options['openstack']['vm'] = {
          'stemcell' => {
            'api_version' => 2,
          },
        }
        options
      end

      it 'does not set agent_id in user data' do
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, network_configuration, nil, environment)

        expect(cloud.compute.servers).not_to have_received(:create).with(hash_including(user_data: /\"agent_id\":/ ))
      end

      it 'does not set env in user data' do
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, network_configuration, nil, environment)

        expect(cloud.compute.servers).not_to have_received(:create).with(hash_including(user_data: /\"env\":/ ))
      end

      it 'sets networks in user data' do
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, network_configuration, nil, environment)

        expect(cloud.compute.servers).to have_received(:create).with(hash_including(user_data: /\"networks\":{\"network_a\":{\"type\":\"dynamic\",\"cloud_properties\":{\"security_groups\":\[\"default\"\]},\"use_dhcp\":true}}/ ))
      end
    end
  end

  context 'when requested cpi api version is 2' do
    let(:cpi_api_version){2}

		it 'sets networks in user data' do
			cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, network_configuration, nil, environment)

			expect(cloud.compute.servers).to have_received(:create).with(hash_including(user_data: /\"networks\":{\"network_a\":{\"type\":\"dynamic\",\"cloud_properties\":{\"security_groups\":\[\"default\"\]},\"use_dhcp\":true}}/ ))
		end

    it 'returns instance_id and network configuration' do
      res = cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, network_configuration, nil, environment)
      expect(res).to be_a(Array)
      expect(res[0]).to eq('i-test')
      expect(res[1]).to eq(network_configuration)
    end

    context 'when stemcell API v1' do
      it 'does not set agent settings in user data' do
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, network_configuration, nil, environment)

        expect(cloud.compute.servers).not_to have_received(:create).with(hash_including(user_data: /\"foo\":/))
      end

      it 'does not set agent_id in user data' do
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, network_configuration, nil, environment)

        expect(cloud.compute.servers).to have_received(:create)
        expect(cloud.compute.servers).not_to have_received(:create).with(hash_including(user_data: /\"agent_id\":/))
      end

      it 'does not set env in user data' do
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, network_configuration, nil, environment)

        expect(cloud.compute.servers).to have_received(:create)
        expect(cloud.compute.servers).not_to have_received(:create).with(hash_including(user_data: /\"env\":/))
      end

      it 'does set registry' do
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, network_configuration, nil, environment)

        expect(cloud.compute.servers).to have_received(:create).with(hash_including(user_data: /\"registry\":/))
      end
    end

    context 'when stemcell API v2' do
      let(:options) do
        options = mock_cloud_options['properties']
        options['openstack']['vm'] = {
          'stemcell' => {
            'api_version' => 2,
          },
        }
        options
      end

      it 'sets agent settings in user data' do
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, network_configuration, nil, environment)

        expect(cloud.compute.servers).to have_received(:create).with(hash_including(user_data: /\"foo\":\"bar\"/))
      end

      it 'sets agent_id in user data' do
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, network_configuration, nil, environment)

        expect(cloud.compute.servers).to have_received(:create).with(hash_including(user_data: /\"agent_id\":\"agent-id\"/))
      end

      it 'sets env in user data' do
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, network_configuration, nil, environment)

        expect(cloud.compute.servers).to have_received(:create).with(hash_including(
          user_data: /\"env\":{\"test_env\":\"value\"}/))
      end

      it 'does not set registry' do
        cloud.create_vm('agent-id', 'sc-id', resource_pool_spec, network_configuration, nil, environment)

        expect(cloud.compute.servers).not_to have_received(:create).with(hash_including(user_data: /\"registry\":/))
      end
    end
  end
end
