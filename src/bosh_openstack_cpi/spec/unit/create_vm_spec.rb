# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"
require 'excon/errors'
require 'excon'

describe Bosh::OpenStackCloud::Cloud, "create_vm" do

  def agent_settings(unique_name, network_spec = dynamic_network_spec, ephemeral = "/dev/sdb")
    {
      "vm" => {
        "name" => "vm-#{unique_name}"
      },
      "agent_id" => "agent-id",
      "networks" => { "network_a" => network_spec },
      "disks" => {
        "system" => "/dev/sda",
        "ephemeral" => ephemeral,
        "persistent" => {}
      },
      "env" => {
        "test_env" => "value"
      },
      "foo" => "bar", # Agent env
      "baz" => "zaz"
    }
  end

  def openstack_params(network_spec = { "network_a" => dynamic_network_spec}, boot_from_volume = false )
    params = {
      name: "vm-#{unique_name}",
      image_ref: "sc-id",
      flavor_ref: "f-test",
      key_name: "test_key",
      security_groups: configured_security_groups,
      os_scheduler_hints: scheduler_hints,
      nics: nics,
      config_drive: false,
      user_data: JSON.dump(user_data(unique_name, network_spec, nameserver, false)),
      availability_zone: "foobar-1a"
    }

    if boot_from_volume
      params.delete(:image_ref)
      params[:block_device_mapping_v2] = [{
        :uuid => "sc-id",
        :source_type => "image",
        :destination_type => "volume",
        :volume_size => 2,
        :boot_index => "0",
        :delete_on_termination => "1",
        :device_name => "/dev/vda" }]
    end

    params
  end

  def user_data(unique_name, network_spec, nameserver = nil, openssh = false)
    user_data = {
      "registry" => {
          "endpoint" => "http://registry:3333"
      },
      "server" => {
          "name" => "vm-#{unique_name}"
      }
    }
    user_data["openssh"] = { "public_key" => "public openssh key" } if openssh
    user_data["networks"] = network_spec
    user_data["dns"] = { "nameserver" => [nameserver] } if nameserver
    user_data
  end

  let(:unique_name) { SecureRandom.uuid }
  let(:server) { double("server", :id => "i-test", :name => "i-test") }
  let(:image) { double("image", :id => "sc-id", :name => "sc-id") }
  let(:flavor) { double("flavor", :id => "f-test", :name => "m1.tiny", :ram => 1024, :disk => 2, :ephemeral => 2) }
  let(:key_pair) { double("key_pair", :id => "k-test", :name => "test_key",
                   :fingerprint => "00:01:02:03:04", :public_key => "public openssh key") }
  let(:configured_security_groups) { %w[default] }
  let(:nameserver) { nil }
  let(:nics) { [] }
  let(:scheduler_hints) { nil }

  before(:each) do
    @registry = mock_registry
    allow(Bosh::OpenStackCloud::TagManager).to receive(:tag)
  end

  def stub_compute(compute)
    allow(compute.flavors).to receive(:find).and_return(flavor)
    allow(compute.key_pairs).to receive(:find).and_return(key_pair)
  end

  it "creates an OpenStack server and polls until it's ready" do
    cloud = mock_cloud do |fog|
      expect(fog.compute.servers).to receive(:create).with(openstack_params).and_return(server)
      allow(fog.image.images).to receive(:find_by_id).and_return(image)
      stub_compute(fog.compute)
    end

    expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
    expect(cloud).to receive(:wait_resource).with(server, :active, :state)

    expect(@registry).to receive(:update_settings).
        with("vm-#{unique_name}", agent_settings(unique_name))

    vm_id = cloud.create_vm("agent-id", "sc-id",
                            resource_pool_spec,
                            { "network_a" => dynamic_network_spec },
                            nil, { "test_env" => "value" })
    expect(vm_id).to eq("i-test")
  end

  describe 'multi-homed VMs' do

    let(:cloud) do
      cloud_options = mock_cloud_options['properties']
      cloud_options["openstack"].merge!({
          'config_drive' => 'cdrom',
          'use_dhcp' => false,
          'use_nova_networking' => false
      })

      mock_cloud(cloud_options) do |openstack|
        allow(openstack.compute.servers).to receive(:create).and_return(server)
        allow(openstack.image.images).to receive(:find_by_id).and_return(image)
        allow(openstack.compute.flavors).to receive(:find).and_return(flavor)
        allow(openstack.compute.key_pairs).to receive(:find).and_return(key_pair)
        port_result_net = double('ports1', id: '117717c1-81cb-4ac4-96ab-99aaf1be9ca8', network_id: 'net', mac_address: 'AA:AA:AA:AA:AA:AA')
        ports = double('Fog::Network::OpenStack::Ports')
        allow(ports).to receive(:create).with(network_id: 'net', fixed_ips: [{ip_address: '10.0.0.1'}], security_groups: ['default_sec_group_id']).and_return(port_result_net)
        allow(openstack.network).to receive(:ports).and_return(ports)
      end
    end
    let(:network_spec) { {'network_a' => manual_network_spec(ip: '10.0.0.1')} }
    let(:expected_network_spec) { {'network_a' => manual_network_spec(ip: '10.0.0.1', overwrites: {'mac' => 'AA:AA:AA:AA:AA:AA', 'use_dhcp' => false})} }
    let(:nics) { [{'net_id' => 'net', 'port_id' => '117717c1-81cb-4ac4-96ab-99aaf1be9ca8'}] }

    it 'creates an OpenStack server with config drive and mac addresses' do


      allow(cloud).to receive(:generate_unique_name).and_return(unique_name)
      allow(cloud).to receive(:wait_resource)#.with(server, :active, :state)

      allow(@registry).to receive(:update_settings)#.with("vm-#{unique_name}", agent_settings(unique_name, network_spec))

      vm_id = cloud.create_vm('agent-id', 'sc-id',
          resource_pool_spec,
          network_spec,
          nil,
          {'test_env' => 'value'}
      )

      expect(cloud.compute.servers).to have_received(:create).with(openstack_params(expected_network_spec).merge(config_drive: true))
    end
  end

  context "with nameserver" do
    let(:nameserver) { "1.2.3.4" }

    it "passes dns servers in server user data when present" do
      network_spec = dynamic_network_spec
      network_spec["dns"] = [nameserver]

      cloud = mock_cloud do |fog|
        expect(fog.compute.servers).to receive(:create).with(openstack_params("network_a" => network_spec)).and_return(server)
        expect(fog.image.images).to receive(:find_by_id).and_return(image)
        expect(fog.compute.flavors).to receive(:find).and_return(flavor)
        expect(fog.compute.key_pairs).to receive(:find).and_return(key_pair)
      end

      expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
      expect(cloud).to receive(:wait_resource).with(server, :active, :state)

      expect(@registry).to receive(:update_settings).
        with("vm-#{unique_name}", agent_settings(unique_name, network_spec))

      vm_id = cloud.create_vm("agent-id", "sc-id",
        resource_pool_spec,
        { "network_a" => network_spec },
        nil, { "test_env" => "value" })
      expect(vm_id).to eq("i-test")
    end
  end

  context "with security groups" do
    let(:network_with_security_group_spec) {
      ns = dynamic_network_spec
      ns["cloud_properties"] ||= {}
      ns["cloud_properties"]["security_groups"] = %w[net-group-1 net-group-2]
      ns
    }

    let(:resource_pool_with_security_group_spec) {
      rps = resource_pool_spec
      rps["security_groups"] = %w[pool-group-1 pool-group-2]
      rps
    }

    context "defined in both network or resource_pools spec" do
      let(:configured_security_groups) { %w[security-group-1 security-group-2] }

      it "raises an error when attempting to create an OpenStack server" do
        address = double("address", :id => "a-test", :ip => "10.0.0.1", :instance_id => nil)

        cloud = mock_cloud
        expect(cloud).to receive(:generate_unique_name).and_return(unique_name)

        expect {
          cloud.create_vm("agent-id", "sc-id",
            resource_pool_with_security_group_spec,
            { "network_a" => network_with_security_group_spec },
            nil, { "test_env" => "value" })
        }.to raise_error('Cannot define security groups in both network and resource pool.')
      end
    end

    context "defined in network spec" do
      let(:openstack_security_groups) { [
          double('net-group-1', id: 'net-group-1_id', name: 'net-group-1'),
          double('net-group-2', id: 'net-group-2_id', name: 'net-group-2')
      ] }

      let(:configured_security_groups) { %w[net-group-1 net-group-2] }

      it "creates an OpenStack server" do
        cloud = mock_cloud do |fog|
          expect(fog.compute.servers).to receive(:create).with(openstack_params("network_a" => network_with_security_group_spec)).and_return(server)
          expect(fog.network).to receive(:security_groups).and_return(openstack_security_groups)
          expect(fog.image.images).to receive(:find_by_id).and_return(image)
          expect(fog.compute.flavors).to receive(:find).and_return(flavor)
          expect(fog.compute.key_pairs).to receive(:find).and_return(key_pair)
        end

        expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
        expect(cloud).to receive(:wait_resource).with(server, :active, :state)
        expect(@registry).to receive(:update_settings).with("vm-#{unique_name}", agent_settings(unique_name, network_with_security_group_spec))

        vm_id = cloud.create_vm("agent-id", "sc-id",
          resource_pool_spec,
          { "network_a" => network_with_security_group_spec },
          nil, { "test_env" => "value" })
        expect(vm_id).to eq("i-test")
      end
    end

    context "defined in resource_pools spec" do

      let(:openstack_security_groups) { [
          double('pool-group-1', id: 'pool-group-1_id', name: 'pool-group-1'),
          double('pool-group-2', id: 'pool-group-2_id', name: 'pool-group-2')
      ] }

      let(:configured_security_groups) { %w[pool-group-1 pool-group-2] }

      let(:dynamic_network_without_security_group_spec) do
        ns = dynamic_network_spec
        ns["cloud_properties"] = {}
        ns
      end

      it "creates an OpenStack server" do
        cloud = mock_cloud do |fog|
          expect(fog.compute.servers).to receive(:create).with(openstack_params("network_a" => dynamic_network_without_security_group_spec)).and_return(server)
          expect(fog.network).to receive(:security_groups).and_return(openstack_security_groups)
          expect(fog.image.images).to receive(:find_by_id).and_return(image)
          expect(fog.compute.flavors).to receive(:find).and_return(flavor)
          expect(fog.compute.key_pairs).to receive(:find).and_return(key_pair)
        end

        expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
        expect(cloud).to receive(:wait_resource).with(server, :active, :state)
        expect(@registry).to receive(:update_settings).with("vm-#{unique_name}", agent_settings(unique_name, dynamic_network_without_security_group_spec))

        vm_id = cloud.create_vm("agent-id", "sc-id",
          resource_pool_with_security_group_spec,
          { "network_a" => dynamic_network_without_security_group_spec },
          nil, { "test_env" => "value" })
        expect(vm_id).to eq("i-test")
      end
    end
  end

  context "with nic for dynamic network" do
    let(:nics) do
      [
        {"net_id" => "foo"}
      ]
    end

    it "creates an OpenStack server with nic for dynamic network" do
      network_spec = dynamic_network_spec
      network_spec["cloud_properties"] ||= {}
      network_spec["cloud_properties"]["net_id"] = nics[0]["net_id"]

      cloud = mock_cloud do |fog|
        expect(fog.compute.servers).to receive(:create).with(openstack_params("network_a" => network_spec)).and_return(server)
        expect(fog.image.images).to receive(:find_by_id).and_return(image)
        expect(fog.compute.flavors).to receive(:find).and_return(flavor)
        expect(fog.compute.key_pairs).to receive(:find).and_return(key_pair)
      end

      expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
      expect(cloud).to receive(:wait_resource).with(server, :active, :state)

      expect(@registry).to receive(:update_settings).
        with("vm-#{unique_name}", agent_settings(unique_name, network_spec))

      vm_id = cloud.create_vm("agent-id", "sc-id",
        resource_pool_spec,
        { "network_a" => network_spec },
        nil, { "test_env" => "value" })
      expect(vm_id).to eq("i-test")
    end
  end

  context 'with manual network' do
    before(:each) do
      allow(cloud).to receive(:generate_unique_name).and_return(unique_name)
      allow(cloud).to receive(:wait_resource).with(server, :active, :state)
      allow(cloud.registry).to receive(:update_settings)
    end
    let(:several_manual_networks) do
      {
          'network_a' => manual_network_spec(ip: '10.0.0.1'),
          'network_b' => manual_network_spec(net_id: 'bar', ip: '10.0.0.2')
      }
    end

    let(:nics) { [{'net_id' => 'net', 'v4_fixed_ip' => '10.0.0.1'}, {'net_id' => 'bar', 'v4_fixed_ip' => '10.0.0.2'}] }
    let(:configured_security_groups) { %w[default default] }
    let(:cloud_options) do
      cloud_options = mock_cloud_options
      cloud_options['properties']['openstack']['config_drive'] = 'cdrom'
      cloud_options['properties']['openstack']['use_dhcp'] = false
      cloud_options
    end

    let(:cloud) do
      mock_cloud(cloud_options["properties"]) do |fog|
        allow(fog.compute.servers).to receive(:create).and_return(server)
        allow(fog.image.images).to receive(:find_by_id).and_return(image)
        allow(fog.compute.flavors).to receive(:find).and_return(flavor)
        allow(fog.compute.key_pairs).to receive(:find).and_return(key_pair)
      end
    end

    it 'calls NetworkConfigurator#prepare and NetworkConfigurator#nics' do
      expect_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:prepare).with(anything, ['default_sec_group_id'])
      expect_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:nics).and_return(nics)

      cloud.create_vm("agent-id", "sc-id",
          resource_pool_spec,
          several_manual_networks,
          nil, { "test_env" => "value" })
    end

    context 'when vm creation fails' do

      let(:cloud) do
        mock_cloud(cloud_options["properties"]) do |fog|
          allow(fog.compute.servers).to receive(:create).and_raise 'BOOM!!!'
          allow(fog.image.images).to receive(:find_by_id).and_return(image)
          allow(fog.compute.flavors).to receive(:find).and_return(flavor)
          allow(fog.compute.key_pairs).to receive(:find).and_return(key_pair)
        end
      end

      it 'calls NetworkConfigurator#cleanup' do
        allow_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:prepare)

        expect_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:cleanup)
        expect{
          cloud.create_vm('agent-id', 'sc-id',
              resource_pool_spec,
              { 'network_a' => manual_network_spec(ip: '10.0.0.1') },
              nil, { 'test_env' => 'value'})

        }.to raise_error RuntimeError, 'BOOM!!!'
      end

      context 'when NetworkConfigurator#cleanup fails' do
        it 'fails with the vm creation failure' do
          allow_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:prepare)

          expect_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:cleanup).and_raise 'BOOM Cleanup!!!'
          expect{
            cloud.create_vm('agent-id', 'sc-id',
                resource_pool_spec,
                { 'network_a' => manual_network_spec(ip: '10.0.0.1') },
                nil, { 'test_env' => 'value'})

          }.to raise_error RuntimeError, 'BOOM!!!'
        end
      end

      context 'when vm_destroy fails' do
        let(:cloud) do
          mock_cloud(cloud_options["properties"]) do |fog|
            allow(fog.compute.servers).to receive(:create).and_return(server)
            allow(server).to receive(:destroy).and_raise 'BOOM!!!'
            allow(fog.image.images).to receive(:find_by_id).and_return(image)
            allow(fog.compute.flavors).to receive(:find).and_return(flavor)
            allow(fog.compute.key_pairs).to receive(:find).and_return(key_pair)
          end
        end

        it 'calls NetworkConfigurator#cleanup and fails with vm creatin failer' do
          allow_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:prepare)
          allow_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:configure).and_raise 'BOOM configure!!!'

          expect_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:cleanup)
          expect{
            cloud.create_vm('agent-id', 'sc-id',
                resource_pool_spec,
                { 'network_a' => manual_network_spec(ip: '10.0.0.1') },
                nil, { 'test_env' => 'value'})

          }.to raise_error Bosh::Clouds::VMCreationFailed, 'BOOM configure!!!'
        end
      end
    end
  end

  context "with scheduler hints" do
    let(:scheduler_hints) do
      {group: 'abcd-foo-bar'}
    end

    it "creates an OpenStack server with scheduler hints" do
      cloud = mock_cloud do |fog|
        expect(fog.compute.servers).to receive(:create).with(openstack_params(combined_network_spec)).and_return(server)
        expect(fog.image.images).to receive(:find_by_id).and_return(image)
        expect(fog.compute.flavors).to receive(:find).and_return(flavor)
        expect(fog.compute.key_pairs).to receive(:find).and_return(key_pair)
      end

      expect(cloud).to receive(:generate_unique_name).and_return(openstack_params[:name].gsub(/^vm-/,''))
      expect(cloud).to receive(:wait_resource).with(server, :active, :state)
      expect_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:configure)

      expect(@registry).to receive(:update_settings)

      cloud.create_vm("agent-id", "sc-id",
                      resource_pool_spec.merge('scheduler_hints' => scheduler_hints),
                      combined_network_spec)
    end
  end

  context "when boot_from_volume is set" do
    it "creates an OpenStack server with a boot volume" do
      network_spec = dynamic_network_spec

      cloud_options = mock_cloud_options
      cloud_options['properties']['openstack']['boot_from_volume'] = true

      cloud = mock_cloud(cloud_options['properties']) do |fog|
        expect(fog.compute.servers).to receive(:create).with(openstack_params({"network_a" => network_spec}, true)).and_return(server)
        expect(fog.image.images).to receive(:find_by_id).and_return(image)
        expect(fog.compute.flavors).to receive(:find).and_return(flavor)
        expect(fog.compute.key_pairs).to receive(:find).and_return(key_pair)
      end

      expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
      expect(cloud).to receive(:wait_resource).with(server, :active, :state)

      expect(@registry).to receive(:update_settings).
        with("vm-#{unique_name}", agent_settings(unique_name, network_spec))

      vm_id = cloud.create_vm("agent-id", "sc-id",
        resource_pool_spec,
        { "network_a" => network_spec },
        nil, { "test_env" => "value" })
      expect(vm_id).to eq("i-test")
    end
  end

  context "when boot_from_volume is set with a volume_type" do

    it "creates an OpenStack server with a boot volume" do
      network_spec = dynamic_network_spec

      cloud_options = mock_cloud_options
      cloud_options['properties']['openstack']['boot_from_volume'] = true
      cloud_options['properties']['openstack']['boot_volume_cloud_properties'] = {
        "type" => "foo"
      }

      cloud = mock_cloud(cloud_options['properties']) do |fog|
        expect(fog.compute.servers).to receive(:create).with(openstack_params({"network_a" => network_spec}, true)).and_return(server)
        expect(fog.image.images).to receive(:find_by_id).and_return(image)
        expect(fog.compute.flavors).to receive(:find).and_return(flavor)
        expect(fog.compute.key_pairs).to receive(:find).and_return(key_pair)
      end

      expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
      expect(cloud).to receive(:wait_resource).with(server, :active, :state)

      expect(@registry).to receive(:update_settings).
        with("vm-#{unique_name}", agent_settings(unique_name, network_spec))

      vm_id = cloud.create_vm("agent-id", "sc-id",
        resource_pool_spec,
        { "network_a" => network_spec },
        nil, { "test_env" => "value" })

      expect(vm_id).to eq("i-test")
    end
  end

  context "when config_drive option is set" do
    it "creates an OpenStack server with config drive" do
      cloud_options = mock_cloud_options
      cloud_options["properties"]["openstack"]["config_drive"] = 'cdrom'
      network_spec = dynamic_network_spec

      cloud = mock_cloud(cloud_options['properties']) do |fog|
        expect(fog.compute.servers).to receive(:create).with(openstack_params.merge(config_drive: true)).and_return(server)
        expect(fog.image.images).to receive(:find_by_id).and_return(image)
        expect(fog.compute.flavors).to receive(:find).and_return(flavor)
        expect(fog.compute.key_pairs).to receive(:find).and_return(key_pair)
      end

      allow(cloud).to receive(:generate_unique_name).and_return(unique_name)
      allow(cloud).to receive(:wait_resource).with(server, :active, :state)

      allow(@registry).to receive(:update_settings).with("vm-#{unique_name}", agent_settings(unique_name, network_spec))

      vm_id = cloud.create_vm("agent-id", "sc-id",
        resource_pool_spec,
        {"network_a" => network_spec},
        nil,
        {"test_env" => "value"}
      )

      expect(vm_id).to eq("i-test")
    end
  end

  context "when cannot create an OpenStack server" do
    let(:cloud) do
      mock_cloud do |fog|
        allow(fog.compute.servers).to receive(:create).and_return(server)
        allow(fog.image.images).to receive(:find_by_id).and_return(image)
        allow(fog.compute.flavors).to receive(:find).and_return(flavor)
        allow(fog.compute.key_pairs).to receive(:find).and_return(key_pair)
      end
    end

    context "when OpenStack raises a Timeout error" do
      let(:socket_error) { Excon::Errors::Timeout.new('read timeout reached') }
      it "raises a Cloud error with vm information" do
        allow(cloud).to receive(:generate_unique_name).and_return(unique_name)
        allow(cloud.compute.servers).to receive(:create).and_raise(socket_error)

        expect {
          cloud.create_vm(
              "agent-id",
              "sc-id",
              resource_pool_spec,
              {"network_a" => dynamic_network_spec},
              nil,
              {"test_env" => "value"}
          )
        }.to raise_error(Bosh::Clouds::VMCreationFailed, /'vm-#{unique_name}'.*?\nOriginal message: read timeout reached/)
      end
    end

    context "when OpenStack raises a Not Found error" do
      let(:networks) { double('networks') }
      let(:not_found_error) { Excon::Errors::NotFound.new('not found: 814bc266-c6de-4fd0-a713-502da09edbe9') }

      let(:cloud) {
        cloud = mock_cloud do |fog|
          allow(fog.compute.servers).to receive(:create).and_raise(not_found_error)
          allow(fog.image.images).to receive(:find_by_id).and_return(image)
          allow(fog.compute.flavors).to receive(:find).and_return(flavor)
          allow(fog.compute.key_pairs).to receive(:find).and_return(key_pair)
          allow(fog.network).to receive(:networks).and_return(networks)
        end

        allow(cloud).to receive(:generate_unique_name).and_return(unique_name)

        cloud
      }

      it 'raises a VMCreationFailed error with subnet ID' do
        allow(networks).to receive(:get).and_return(nil)

        expect {
          cloud.create_vm(
              "agent-id",
              "sc-id",
              resource_pool_spec,
              {"network_a" => dynamic_network_with_netid_spec},
              nil,
              {"test_env" => "value"}
          )
        }.to raise_error(Bosh::Clouds::VMCreationFailed, /'vm-#{unique_name}'.*?'net'/)
      end

      it 'raises a Not Found error with existing Net IDs' do
        allow_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:prepare)
        allow_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:cleanup)
        allow(networks).to receive(:get).and_return('some_network')
        network_with_different_net_id = manual_network_spec(net_id: 'some_other_id')

        expect {
          cloud.create_vm(
              "agent-id",
              "sc-id",
              resource_pool_spec,
              {"network_b" => network_with_different_net_id},
              nil,
              {"test_env" => "value"}
          )
        }.to raise_error(Excon::Errors::NotFound, 'not found: 814bc266-c6de-4fd0-a713-502da09edbe9')
      end

      context 'when `openstack.network.networks.get` raises' do

        before(:each) do
          allow(networks).to receive(:get).and_raise('BOOM!!!')
        end

        it 'raises the original error' do
          allow_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:prepare)
          allow_any_instance_of(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:cleanup)
          network_with_different_net_id = manual_network_spec(net_id: 'some_other_id')

          expect {
            cloud.create_vm(
                "agent-id",
                "sc-id",
                resource_pool_spec,
                {"network_b" => network_with_different_net_id},
                nil,
                {"test_env" => "value"}
            )
          }.to raise_error(Excon::Errors::NotFound, 'not found: 814bc266-c6de-4fd0-a713-502da09edbe9')
        end
      end

      context 'when `use_nova_networking=true`' do
        let(:cloud_options) {
          mocked_options = mock_cloud_options(3)
          mocked_options['properties']['openstack']['use_nova_networking'] = true
          mocked_options['properties']
        }

        let(:cloud) {
          cloud = mock_cloud(cloud_options) do |openstack|
            allow(openstack.compute.servers).to receive(:create).and_raise(not_found_error)
            allow(openstack.image.images).to receive(:find_by_id).and_return(image)
            allow(openstack.compute.flavors).to receive(:find).and_return(flavor)
            allow(openstack.compute.key_pairs).to receive(:find).and_return(key_pair)
            security_groups = [double('default_sec_group', id: 'default_sec_group_id', name: 'default')]
            allow(openstack.compute).to receive(:security_groups).and_return(security_groups)

            expect(openstack.network).to_not receive(:networks)
          end

          allow(cloud).to receive(:generate_unique_name).and_return(unique_name)

          cloud
        }

        it "raises a Not Found error with Network service not available" do
          expect {
            cloud.create_vm(
                "agent-id",
                "sc-id",
                resource_pool_spec,
                {"network_a" => dynamic_network_with_netid_spec},
                nil,
                {"test_env" => "value"}
            )
          }.to raise_error(Excon::Errors::NotFound)
        end
      end
    end

    context "when OpenStack raises a BadRequest error" do
      let(:networks) { double('networks') }
      let(:bad_request_error) { Excon::Errors::BadRequest.new('Message does not matter here') }

      let(:cloud) {
        cloud = mock_cloud do |fog|
          allow(fog.compute.servers).to receive(:create).and_raise(bad_request_error)
          allow(fog.image.images).to receive(:find_by_id).and_return(image)
          allow(fog.compute.flavors).to receive(:find).and_return(flavor)
          allow(fog.compute.key_pairs).to receive(:find).and_return(key_pair)
          allow(fog.network).to receive(:networks).and_return(networks)
        end

        allow(cloud).to receive(:generate_unique_name).and_return(unique_name)

        cloud
      }

      it "raises a VMCreationFailed error with subnet ID" do
        allow(networks).to receive(:get).and_return(nil)

        expect {
          cloud.create_vm(
              "agent-id",
              "sc-id",
              resource_pool_spec,
              {"network_a" => dynamic_network_with_netid_spec},
              nil,
              {"test_env" => "value"}
          )
        }.to raise_error(Bosh::Clouds::VMCreationFailed, /'vm-#{unique_name}'.*?'net'/)
      end
    end

    it "destroys the server successfully and raises a Retryable Error" do
      allow(server).to receive(:destroy)

      allow(cloud).to receive(:wait_resource).with(server, :active, :state).and_raise(Bosh::Clouds::CloudError)
      expect(cloud).to receive(:wait_resource).with(server, [:terminated, :deleted], :state, true)

      expect {
        cloud.create_vm(
          "agent-id",
          "sc-id",
          resource_pool_spec,
          {"network_a" => dynamic_network_spec},
          nil,
          {"test_env" => "value"}
        )
      }.to raise_error(Bosh::Clouds::VMCreationFailed)

      allow(cloud).to receive(:wait_resource).with(server, :active, :state).and_raise(StandardError)
      expect(cloud).to receive(:wait_resource).with(server, [:terminated, :deleted], :state, true)

      expect {
        cloud.create_vm(
          "agent-id",
          "sc-id",
          resource_pool_spec,
          {"network_a" => dynamic_network_spec},
          nil,
          {"test_env" => "value"}
        )
      }.to raise_error(Bosh::Clouds::VMCreationFailed)
    end

    it "raises a Retryable Error and logs correct failure message when failed to destroy the server" do
      allow(server).to receive(:destroy)
      allow(cloud).to receive(:wait_resource).with(server, :active, :state).and_raise(Bosh::Clouds::CloudError)
      allow(cloud).to receive(:wait_resource).with(server, [:terminated, :deleted], :state, true).and_raise(Bosh::Clouds::CloudError)

      expect(Bosh::Clouds::Config.logger).to receive(:warn).with('Failed to create server: Bosh::Clouds::CloudError')
      expect(Bosh::Clouds::Config.logger).to receive(:warn).with(/Failed to destroy server:.*/)

      expect {
        cloud.create_vm(
          "agent-id",
          "sc-id",
          resource_pool_spec,
          {"network_a" => dynamic_network_spec},
          nil,
          {"test_env" => "value"}
        )
      }.to raise_error(Bosh::Clouds::VMCreationFailed)
    end
  end

  context "when fail to connect to find image on OpenStack server" do
    let(:cloud) do
      mock_cloud do |fog|
        allow(fog.compute.servers).to receive(:create).and_return(server)
        allow(fog.compute.flavors).to receive(:find).and_return(flavor)
        allow(fog.compute.key_pairs).to receive(:find).and_return(key_pair)
      end
    end
    let(:error) do
      Excon::Errors::SocketError.new(Excon::Errors::Error.new)
    end

    it "retries 5 times" do
      expect(cloud.glance.images).to receive(:find_by_id).ordered.exactly(5).times.and_raise(error)
      expect{cloud.create_vm(
        "agent-id",
        "sc-id",
        resource_pool_spec,
        { "network_a" => dynamic_network_spec },
        nil,
        { "test_env" => "value" }
      )}.to raise_error(Bosh::Clouds::CloudError)
    end
  end

  context "when fail to register an OpenStack server after the server is created" do
    let(:cloud) do
      mock_cloud do |fog|
        allow(fog.compute.servers).to receive(:create).and_return(server)
        allow(fog.image.images).to receive(:find_by_id).and_return(image)
        allow(fog.compute.flavors).to receive(:find).and_return(flavor)
        allow(fog.compute.key_pairs).to receive(:find).and_return(key_pair)
      end
    end

    before do
      allow(cloud).to receive(:wait_resource).with(server, :active, :state)
    end

    it "destroys the server successfully and raises a non-retryable Error when CloudError happens" do
      allow(server).to receive(:destroy)

      allow(@registry).to receive(:update_settings).and_raise(Bosh::Clouds::CloudError)
      expect(cloud).to receive(:wait_resource).with(server, [:terminated, :deleted], :state, true)

      expect {
        cloud.create_vm(
          "agent-id",
          "sc-id",
          resource_pool_spec,
          { "network_a" => dynamic_network_spec },
          nil,
          { "test_env" => "value" })
      }.to raise_error { |error|
             expect(error).to be_a(Bosh::Clouds::VMCreationFailed)
             expect(error.ok_to_retry).to eq(false)
           }

      allow(@registry).to receive(:update_settings).and_raise(StandardError)
      expect(cloud).to receive(:wait_resource).with(server, [:terminated, :deleted], :state, true)

      expect {
        cloud.create_vm(
          "agent-id",
          "sc-id",
          resource_pool_spec,
          { "network_a" => dynamic_network_spec },
          nil,
          { "test_env" => "value" })
      }.to raise_error { |error|
             expect(error).to be_a(Bosh::Clouds::VMCreationFailed)
             expect(error.ok_to_retry).to eq(false)
           }
    end

    it "logs correct failure message when failed to destroy the server" do
      allow(@registry).to receive(:update_settings).and_raise(Bosh::Clouds::CloudError)
      allow(server).to receive(:destroy)
      allow(cloud).to receive(:wait_resource).with(server, [:terminated, :deleted], :state, true).and_raise(Bosh::Clouds::CloudError)

      expect(Bosh::Clouds::Config.logger).to receive(:warn).with('Failed to register server: Bosh::Clouds::CloudError')
      expect(Bosh::Clouds::Config.logger).to receive(:warn).with(/Failed to destroy server:.*/)

      expect {
        cloud.create_vm(
            "agent-id",
            "sc-id",
            resource_pool_spec,
            { "network_a" => dynamic_network_spec },
            nil,
            { "test_env" => "value" })
      }.to raise_error(Bosh::Clouds::VMCreationFailed)
    end
  end

  context "when security group doesn't exist" do
    let(:openstack_security_groups) { [ double('foo-sec-group', id: 'foo-sec-group-id', name: 'foo') ] }

    it 'raises an error' do
      cloud = mock_cloud do |fog|
        expect(fog.network).to receive(:security_groups).and_return(openstack_security_groups)
      end

      expect {
        cloud.create_vm("agent-id", "sc-id", resource_pool_spec, { "network_a" => dynamic_network_spec },
                        nil, { "test_env" => "value" })
      }.to raise_error(Bosh::Clouds::CloudError, "Security group `default' not found")
    end
  end

  it "raises an error when flavor doesn't have enough ephemeral disk capacity" do
    flavor = double("flavor", :id => "f-test", :name => "m1.tiny", :ram => 1024, :ephemeral => 1)
    cloud = mock_cloud do |fog|
      expect(fog.image.images).to receive(:find_by_id).and_return(image)
      expect(fog.compute.flavors).to receive(:find).and_return(flavor)
    end

    expect {
      cloud.create_vm("agent-id", "sc-id", resource_pool_spec, { "network_a" => dynamic_network_spec },
                      nil, { "test_env" => "value" })
    }.to raise_error(Bosh::Clouds::CloudError, "Flavor `m1.tiny' should have at least 2Gb of ephemeral disk")
  end

  def volume(zone)
    vol = double("volume")
    allow(vol).to receive(:availability_zone).and_return(zone)
    vol
  end

  describe "#select_availability_zone" do
    it "should return nil when all values are nil" do
      cloud = mock_cloud
      expect(cloud.select_availability_zone(nil, nil)).to eq(nil)
    end

    it "should select the resource pool availability_zone when disks are nil" do
      cloud = mock_cloud
      expect(cloud.select_availability_zone(nil, "foobar-1a")).to eq("foobar-1a")
    end

    it "should select the resource pool availability_zone when we are ignoring the disks zone" do
      cloud_options = mock_cloud_options
      cloud_options['properties']['openstack']['boot_from_volume'] = true
      cloud_options['properties']['openstack']['ignore_server_availability_zone'] = true

      cloud = mock_cloud(cloud_options["properties"]) do |fog|
        allow(fog.volume.volumes).to receive(:get).and_return(volume("foo"), volume("foo"))
      end
      expect(cloud.select_availability_zone(%w[cid1 cid2], "foobar-1a")).to eq("foobar-1a")
    end

    it "should select the zone from a list of disks" do
      cloud = mock_cloud do |fog|
        allow(fog.volume.volumes).to receive(:get).and_return(volume("foo"), volume("foo"))
      end
      expect(cloud.select_availability_zone(%w[cid1 cid2], nil)).to eq("foo")
    end

    it "should select the zone from a list of disks and a default" do
      cloud = mock_cloud do |fog|
        allow(fog.volume.volumes).to receive(:get).and_return(volume("foo"), volume("foo"))
      end
      expect(cloud.select_availability_zone(%w[cid1 cid2], "foo")).to eq("foo")
    end
  end

  describe 'failing to select an AZ' do
    it 'should raise an error when the disks are from different zones' do
      cloud = mock_cloud do |fog|
        expect(fog.volume.volumes).to receive(:get).and_return(volume("foo"), volume("bar"))
      end
      expect {
        cloud.select_availability_zone(%w[cid1 cid2], "bar")
      }.to raise_error Bosh::Clouds::CloudError
    end

    it "should raise an error when the disk zones are the same and the resource pool AZ is nil" do
      cloud = mock_cloud do |fog|
        expect(fog.volume.volumes).to receive(:get).and_return(volume("foo"), volume("bar"))
      end
      expect {
        cloud.select_availability_zone(%w[cid1 cid2], nil)
      }.to raise_error Bosh::Clouds::CloudError
    end

    it "should raise an error when the zones differ" do
      cloud = mock_cloud do |fog|
        expect(fog.volume.volumes).to receive(:get).and_return(volume("foo"), volume("foo"))
      end
      expect {
        cloud.select_availability_zone(%w[cid1 cid2], "baz")
      }.to raise_error Bosh::Clouds::CloudError
    end
  end

  context 'when use_dhcp is set to false' do
    it 'updates network settings to include use_dhcp as false' do
      cloud_options = mock_cloud_options["properties"]
      cloud_options["openstack"]["use_dhcp"] = false

      expected_network_spec = dynamic_network_spec
      expected_network_spec["use_dhcp"] = false
      expected_openstack_params = openstack_params({ "network_a" => expected_network_spec })

      cloud = mock_cloud(cloud_options) do |fog|
        expect(fog.compute.servers).to receive(:create).with(expected_openstack_params).and_return(server)
        allow(fog.image.images).to receive(:find_by_id).and_return(image)
        stub_compute(fog.compute)
      end

      expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
      expect(cloud).to receive(:wait_resource).with(server, :active, :state)

      expect(@registry).to receive(:update_settings).
          with("vm-#{unique_name}", agent_settings(unique_name, expected_network_spec))

      vm_id = cloud.create_vm("agent-id", "sc-id",
        resource_pool_spec,
        { "network_a" => dynamic_network_spec },
        nil, { "test_env" => "value" })
      expect(vm_id).to eq("i-test")
    end
  end

  describe 'key_name configuration' do

    def resource_pool_spec_no_key
      {
          'availability_zone' => 'foobar-1a',
          'instance_type' => 'm1.tiny'
      }
    end

    def stub_cloud(cloud)
      allow(cloud).to receive(:generate_unique_name).and_return(unique_name)
      allow(cloud).to receive(:wait_resource).with(server, :active, :state)
      allow(@registry).to receive(:update_settings).with("vm-#{unique_name}", agent_settings(unique_name, dynamic_network_spec))
    end

    context 'when key_name is only defined in resource pool' do
      it 'takes the key_name from resource pool' do
        cloud = mock_cloud do |fog|
          expect(fog.compute.servers).to receive(:create).with(openstack_params).and_return(server)
          allow(fog.image.images).to receive(:find_by_id).and_return(image)
          stub_compute(fog.compute)
        end

        stub_cloud(cloud)

        cloud.create_vm("agent-id", "sc-id",
                                resource_pool_spec,
                                { "network_a" => dynamic_network_spec },
                                nil, { "test_env" => "value" })
      end
    end

    context 'when default_key_name is only defined in CPI cloud properties' do
      it 'takes the key_name from CPI cloud properties' do
        cloud_options_with_default_key_name = mock_cloud_options['properties']
        cloud_options_with_default_key_name['openstack']['default_key_name'] = 'default_key_name'
        expected_openstack_params = openstack_params
        expected_openstack_params[:key_name] = 'default_key_name'

        cloud = mock_cloud(cloud_options_with_default_key_name) do |fog|
          expect(fog.compute.servers).to receive(:create).with(expected_openstack_params).and_return(server)
          allow(fog.image.images).to receive(:find_by_id).and_return(image)
          stub_compute(fog.compute)
        end

        stub_cloud(cloud)
        expect(cloud).to receive(:validate_key_exists).with('default_key_name')

        cloud.create_vm("agent-id", "sc-id",
                                resource_pool_spec_no_key,
                                { "network_a" => dynamic_network_spec },
                                nil, { "test_env" => "value" })
      end
    end

    context 'when default_key_name is defined in CPI cloud properties and key_name in resource pool' do
      it 'takes the key_name from resource pool' do
        cloud_options_with_default_key_name = mock_cloud_options['properties']
        cloud_options_with_default_key_name['openstack']['default_key_name'] = 'default_key_name'

        cloud = mock_cloud(cloud_options_with_default_key_name) do |fog|
          expect(fog.compute.servers).to receive(:create).with(openstack_params).and_return(server)
          allow(fog.image.images).to receive(:find_by_id).and_return(image)
          stub_compute(fog.compute)
        end

        stub_cloud(cloud)
        expect(cloud).to receive(:validate_key_exists).with('test_key')

        cloud.create_vm("agent-id", "sc-id",
                        resource_pool_spec,
                        { "network_a" => dynamic_network_spec },
                        nil, { "test_env" => "value" })
      end
    end

    context 'when no key_name is defined' do
      it 'raises cloud error' do
        cloud = mock_cloud do |fog|
          stub_compute(fog.compute)
          allow(fog.image.images).to receive(:find_by_id).and_return(image)
          allow(fog.compute).to receive(:key_pairs).and_return([key_pair])
        end
        stub_cloud(cloud)

        expect {
          cloud.create_vm("agent-id", "sc-id",
                          resource_pool_spec_no_key,
                          { "network_a" => dynamic_network_spec },
                          nil, { "test_env" => "value" })
        }.to raise_error(Bosh::Clouds::CloudError, "Key-pair `' not found")
      end
    end
  end

  describe 'use "vm-<uuid>" as registry key' do
    before(:each) do
      allow(cloud).to receive(:generate_unique_name).and_return(unique_name)
      allow(cloud).to receive(:wait_resource)
    end

    let(:cloud) do
      mock_cloud(options) do |fog|
        allow(fog.image.images).to receive(:find_by_id).and_return(image)
        allow(fog.compute.servers).to receive(:create).and_return(server)
        stub_compute(fog.compute)
      end
    end

    context 'when "human_readable_vm_names" is enabled' do
      let(:options) do
        options = mock_cloud_options['properties']
        options['openstack']['human_readable_vm_names'] = true
        options
      end

      it 'tags registry_key with "vm-<uuid>"' do
        allow(@registry).to receive(:update_settings)

        expect(Bosh::OpenStackCloud::TagManager).to receive(:tag).with(server, :registry_key, "vm-#{unique_name}")

        cloud.create_vm("agent-id", "sc-id",
                        resource_pool_spec,
                        { "network_a" => dynamic_network_spec },
                        nil, { "test_env" => "value" })

      end

      it 'raises an exception, if tagging fails' do
        allow(Bosh::OpenStackCloud::TagManager).to receive(:tag).and_raise(StandardError)

        expect(server).to receive(:destroy)
        expect {
          cloud.create_vm("agent-id", "sc-id",
                          resource_pool_spec,
                          { "network_a" => dynamic_network_spec },
                          nil, { "test_env" => "value" })
        }.to raise_error(Bosh::Clouds::CloudError)
      end

      it 'logs human_readable_vm_names enabled' do
        allow(@registry).to receive(:update_settings)

        allow(Bosh::OpenStackCloud::TagManager).to receive(:tag)
        # Bosh.retryable requires us to return a non-nil value from debug
        allow(Bosh::Clouds::Config.logger).to receive(:debug).and_return('logged')

        cloud.create_vm("agent-id", "sc-id",
                        resource_pool_spec,
                        { "network_a" => dynamic_network_spec },
                        nil, { "test_env" => "value" })

        expect(Bosh::Clouds::Config.logger).to have_received(:debug).with("'human_readable_vm_names' enabled")
        expect(Bosh::Clouds::Config.logger).to have_received(:debug).with("Tagged VM 'i-test' with tag 'registry_key': vm-#{unique_name}")
      end
    end

    context 'when "human_readable_vm_names" is disabled' do
      let(:options) do
        options = mock_cloud_options['properties']
      end

      it 'does not tag server with registry tag' do
        allow(@registry).to receive(:update_settings)

        expect(Bosh::OpenStackCloud::TagManager).to_not receive(:tag).with(server, :registry_key, "vm-#{unique_name}")

        cloud.create_vm("agent-id", "sc-id",
                        resource_pool_spec,
                        { "network_a" => dynamic_network_spec },
                        nil, { "test_env" => "value" })

      end

      it 'logs human_readable_vm_names disabled' do
        allow(@registry).to receive(:update_settings)

        allow(Bosh::OpenStackCloud::TagManager).to receive(:tag)
        # Bosh.retryable requires us to return a non-nil value from debug
        allow(Bosh::Clouds::Config.logger).to receive(:debug).and_return('logged')

        cloud.create_vm("agent-id", "sc-id",
                        resource_pool_spec,
                        { "network_a" => dynamic_network_spec },
                        nil, { "test_env" => "value" })

        expect(Bosh::Clouds::Config.logger).to have_received(:debug).with("'human_readable_vm_names' disabled")
      end
    end
  end
end
