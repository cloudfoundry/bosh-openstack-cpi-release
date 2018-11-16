require_relative './spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  before(:all) do
    @config = IntegrationConfig.new
    @cpi_for_stemcell = @config.create_cpi
    @stemcell_id, = upload_stemcell(@cpi_for_stemcell, @config.stemcell_path)
  end

  before { allow(Bosh::Clouds::Config).to receive(:logger).and_return(@config.logger) }

  after(:all) do
    @cpi_for_stemcell.delete_stemcell(@stemcell_id)
  end

  let(:boot_from_volume) { false }
  let(:config_drive) { nil }
  let(:use_dhcp) { true }
  let(:human_readable_vm_names) { false }
  let(:use_nova_networking) { false }
  let(:openstack) { @config.create_openstack }

  subject(:cpi) do
    @config.create_cpi(boot_from_volume: boot_from_volume, config_drive: config_drive, human_readable_vm_names: human_readable_vm_names, use_nova_networking: use_nova_networking, use_dhcp: use_dhcp)
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
            'net_id' => @config.net_id,
          },
        },
      }
    end

    context 'without existing disks and with a floating ip' do
      let(:network_spec_with_vip_network) do
        {
          'vip_network' => {
            'type' => 'vip',
              'ip' => @config.floating_ip,
          },
        }.merge(network_spec)
      end

      before { @vm_with_assigned_floating_ip = create_vm(@stemcell_id, network_spec_with_vip_network, []) }
      after { clean_up_vm(@vm_with_assigned_floating_ip) if @vm_with_assigned_floating_ip }

      it 'exercises the vm lifecycle and reassigns the floating ip' do
        vm_lifecycle(@stemcell_id, network_spec_with_vip_network)
      end
    end

    context 'with existing disks' do
      before do
        @temp_vm_cid = create_vm(@stemcell_id, network_spec, [])
        @existing_volume_id = cpi.create_disk(2048, {}, @temp_vm_cid)
        cpi.delete_vm(@temp_vm_cid)
      end
      after { cpi.delete_disk(@existing_volume_id) if @existing_volume_id }

      it 'exercises the vm lifecycle' do
        expect {
          vm_lifecycle(@stemcell_id, network_spec, @existing_volume_id)
        }.to_not raise_error
      end
    end

    describe 'set_vm_metadata' do
      let(:human_readable_vm_names) { true }
      before { @human_readable_vm_name_id = create_vm(@stemcell_id, network_spec, []) }
      after { clean_up_vm(@human_readable_vm_name_id) if @human_readable_vm_name_id }

      it 'sets the vm name according to the metadata' do
        vm = openstack.compute.servers.get(@human_readable_vm_name_id)
        expect(vm.name).to eq 'openstack_cpi_spec/instance_id'
      end
    end
  end

  describe 'manual network' do
    let(:network_spec) do
      {
        'default' => {
          'type' => 'manual',
          'ip' => @config.manual_ip,
          'cloud_properties' => {
            'net_id' => @config.net_id,
          },
        },
      }
    end

    context 'without existing disks' do
      it 'exercises the vm lifecycle' do
        expect {
          vm_lifecycle(@stemcell_id, network_spec)
        }.to_not raise_error
      end
    end

    context 'with existing disks' do
      before do
        @temp_vm_cid = create_vm(@stemcell_id, network_spec, [])
        @existing_volume_id = cpi.create_disk(2048, {}, @temp_vm_cid)
        clean_up_vm(@temp_vm_cid)
      end

      after { cpi.delete_disk(@existing_volume_id) if @existing_volume_id }

      it 'exercises the vm lifecycle' do
        expect {
          vm_lifecycle(@stemcell_id, network_spec, @existing_volume_id)
        }.to_not raise_error
      end
    end

    context 'with multiple networks and config_drive' do
      let(:multiple_network_spec) do
        {
          'network_1' => {
            'type' => 'manual',
            'ip' => @config.no_dhcp_manual_ip_1,
            'cloud_properties' => {
              'net_id' => @config.net_id_no_dhcp_1,
            },
          },
          'network_2' => {
            'type' => 'manual',
            'ip' => @config.no_dhcp_manual_ip_2,
            'cloud_properties' => {
              'net_id' => @config.net_id_no_dhcp_2,
            },
            'use_dhcp' => false,
          },
        }
      end

      let(:config_drive) { 'cdrom' }
      let(:use_dhcp) { false }

      after { clean_up_vm(@multiple_nics_vm_id) if @multiple_nics_vm_id }

      it 'creates writes the mac addresses of the two networks to the registry' do
        registry = double('registry')
        registry_settings = nil
        allow(Bosh::Cpi::RegistryClient).to receive(:new).and_return(registry)
        allow(registry).to receive_messages(endpoint: nil, delete_settings: nil)
        allow(registry).to receive(:update_settings) do |_, settings|
          registry_settings = settings
        end

        @multiple_nics_vm_id = create_vm(@stemcell_id, multiple_network_spec, [])

        vm = openstack.compute.servers.get(@multiple_nics_vm_id)
        network_interfaces = vm.addresses.map { |_, network_interfaces| network_interfaces }.flatten
        network_interface_1 = network_interfaces.find(&where_ip_address_is(@config.no_dhcp_manual_ip_1))
        network_interface_2 = network_interfaces.find(&where_ip_address_is(@config.no_dhcp_manual_ip_2))

        expect(network_interface_1['OS-EXT-IPS-MAC:mac_addr']).to eq(registry_settings['networks']['network_1']['mac'])
        expect(network_interface_2['OS-EXT-IPS-MAC:mac_addr']).to eq(registry_settings['networks']['network_2']['mac'])

        ports = openstack.with_openstack(retryable: true) { openstack.network.ports.all(device_id: @multiple_nics_vm_id) }
        clean_up_vm(@multiple_nics_vm_id) if @multiple_nics_vm_id

        found_ports = openstack.with_openstack(retryable: true) { ports.find { |port| openstack.network.ports.get port.id } }
        expect(found_ports).to be_nil
      end

      def where_ip_address_is(ip)
        ->(network_interface) { network_interface['addr'] == ip }
      end
    end

    context 'when a neutron port already exists for a given IP' do
      before do
        clean_up_port(@config.manual_ip, @config.net_id)
        openstack.network.create_port(
          @config.net_id,
          fixed_ips: [{ ip_address: @config.manual_ip }],
          security_groups: [@config.security_group_id],
        )
      end

      after do
        clean_up_vm(@vm_id) if @vm_id
        clean_up_port(@config.manual_ip, @config.net_id)
      end

      it 'can still create the VM' do
        expect {
          @vm_id = create_vm(@stemcell_id, network_spec, [])
        }.to_not raise_error
      end

      def clean_up_port(ip, net_id)
        ports = openstack.with_openstack(retryable: true) do
          openstack.network.ports.all("fixed_ips": ["ip_address=#{ip}", "network_id": net_id])
        end

        port_ids = ports.select { |p| p.status == 'DOWN' && p.device_id.empty? && p.device_owner.empty? }.map(&:id)
        openstack.with_openstack(retryable: true) { openstack.network.delete_port(port_ids.first) } unless port_ids.empty?
      end
    end

    context 'with vrrp' do
      before { @vm_with_vrrp_ip = create_vm(@stemcell_id, network_spec, [], { 'allowed_address_pairs' => @config.allowed_address_pairs }) }
      after { clean_up_vm(@vm_with_vrrp_ip) if @vm_with_vrrp_ip }

      it 'adds vrrp_ip as allowed_address_pairs' do
        vrrp_port = openstack.with_openstack(retryable: true) do
          openstack.network.ports.all(fixed_ips: "ip_address=#{@config.manual_ip}")[0]
        end
        port_info = openstack.with_openstack(retryable: true) do
          openstack.network.get_port(vrrp_port.id)
        end
        expect(port_info).to be

        allowed_address_pairs = port_info[:body]['port']['allowed_address_pairs']
        expect(allowed_address_pairs.size).not_to be_zero

        assigned_allowed_address_pairs = allowed_address_pairs[0]['ip_address']

        expect(assigned_allowed_address_pairs).to eq(@config.allowed_address_pairs)
      end
    end
  end

  context 'when booting from volume' do
    let(:boot_from_volume) { true }
    let(:network_spec) do
      {
        'default' => {
          'type' => 'manual',
          'ip' => @config.manual_ip,
          'cloud_properties' => {
            'net_id' => @config.net_id,
          },
        },
      }
    end

    def test_boot_volume(resource_pool = {})
      @vm_id = create_vm(@stemcell_id, network_spec, [], resource_pool)
      volumes = volumes(@vm_id)
      expect(volumes.size).to eq(1)
      expect(volumes.first['device']).to eq('/dev/vda')
    end

    after(:each) { clean_up_vm(@vm_id) if @vm_id }

    it 'creates a vm with boot_volume on /dev/vda' do
      test_boot_volume
    end

    context 'when boot_from_volume defined in the cloud_properties' do
      let(:boot_from_volume) { false }

      it 'creates a vm with boot_volume on /dev/vda' do
        test_boot_volume({ 'boot_from_volume' => true })
      end
    end

    context 'and flavor has root disk size 0' do
      let(:resource_pool) do
        {
          'instance_type' => @config.instance_type_with_no_root_disk,
        }
      end

      context 'and root disk size given in manifest' do
        before do
          resource_pool['root_disk'] = {
            'size' => 20,
          }
        end

        it 'creates a vm with boot_volume on /dev/vda' do
          test_boot_volume
        end
      end

      context 'and root disk size not given in manifest' do
        it 'raises an error' do
          expect {
            vm_lifecycle(@stemcell_id, network_spec, nil, resource_pool)
          }.to raise_error(Bosh::Clouds::CloudError, /Flavor '#{@config.instance_type_with_no_root_disk}' has a root disk size of 0/)
        end
      end
    end
  end

  context 'when using cloud_properties and specifying security groups' do
    let(:security_group) {}
    let(:network_spec) do
      {
        'default' => {
          'type' => 'dynamic',
          'cloud_properties' => {
            'net_id' => @config.net_id,
            'security_groups' => [security_group],
          },
        },
      }
    end

    context 'when security group is specified by name' do
      let(:security_group) { @config.security_group_name }

      it 'exercises the vm lifecycle' do
        expect {
          vm_lifecycle(@stemcell_id, network_spec)
        }.to_not raise_error
      end
    end

    context 'when security group is specified by id' do
      let(:security_group) { @config.security_group_id }

      it 'exercises the vm lifecycle' do
        expect {
          vm_lifecycle(@stemcell_id, network_spec)
        }.to_not raise_error
      end
    end
  end

  context 'when using config drive as cdrom' do
    let(:config_drive) { @config.config_drive }

    let(:network_spec) do
      {
        'default' => {
          'type' => 'dynamic',
          'cloud_properties' => {
            'net_id' => @config.net_id,
          },
        },
      }
    end

    it 'exercises the vm lifecycle' do
      expect {
        vm_lifecycle(@stemcell_id, network_spec)
      }.to_not raise_error
    end
  end

  context 'when vm creation fails' do
    let(:network_spec_that_fails) do
      {
        'default' => {
          'type' => 'manual',
          'ip' => @config.manual_ip,
          'cloud_properties' => {
            'net_id' => @config.net_id,
          },
        },
        'vip' => {
          'type' => 'vip',
          'ip' => '255.255.255.255',
        },
      }
    end

    def no_active_vm_with_ip?(ip)
      openstack.compute.servers.none? do |s|
        s.private_ip_address == ip && [:active].include?(s.state.downcase.to_sym)
      end
    end

    def no_port_remaining?(net_id, ip)
      openstack.with_openstack(retryable: true) do
        openstack.network.ports
               .select { |port| port.network_id == net_id }
               .none? { |port| port.fixed_ips.detect { |ips| ips['ip_address'] == ip } }
      end
    end

    it 'cleans up vm' do
      expect {
        create_vm(@stemcell_id, network_spec_that_fails, [])
      }.to raise_error Bosh::Clouds::VMCreationFailed, /Floating IP '255.255.255.255' not allocated/

      expect(no_active_vm_with_ip?(@config.manual_ip)).to be
      expect(no_port_remaining?(@config.net_id, @config.manual_ip)).to eq(true)
    end

    it 'better error message for wrong net ID' do
      network_spec_with_wrong_net_id = {
        'default' => {
          'type' => 'dynamic',
          'cloud_properties' => {
            'net_id' => '00000000-0000-0000-0000-000000000000',
          },
        },
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
            'net_id' => @config.net_id,
          },
        },
      }
    end

    it 'exercises the vm lifecycles' do
      vm_id = create_vm(@stemcell_id, network_spec, [])

      expect {
        @config.logger.info("Detaching disk vm_id=#{vm_id} disk_id=non-existing-disk")
        cpi.detach_disk(vm_id, 'non-existing-disk')
      }.to_not raise_error

      clean_up_vm(vm_id)
    end
  end

  describe 'use_nova_networking=true' do
    let(:network_spec) do
      {
        'default' => {
          'type' => 'dynamic',
            'cloud_properties' => {
              'net_id' => @config.net_id,
            },
        },
      }
    end

    let(:use_nova_networking) { true }
    after { clean_up_vm(@vm_id_for_nova_compatibility) if @vm_id_for_nova_compatibility }

    it 'create vm does not use neutron for security groups' do
      stub_request(:any, /.*\/v2\.0\/security-groups/)

      @vm_id_for_nova_compatibility = create_vm(@stemcell_id, network_spec, [])

      expect(WebMock).to_not have_requested(:any, /.*\/v2\.0\/security-groups/)
    end
  end

  describe 'light stemcell' do
    let(:light_stemcell_id) { "#{@stemcell_id} light" }

    describe '#create_stemcell' do
      it 'returns the stemcell id with ` light` suffix' do
        cloud_properties = {
          'image_id' => @stemcell_id,
        }

        expect(cpi.create_stemcell('not_relevant_path', cloud_properties)).to eq(light_stemcell_id)
      end

      context 'when referenced image does not exist' do
        it 'raises an error' do
          cloud_properties = {
            'image_id' => 'non-existing-id',
          }

          expect {
            cpi.create_stemcell('not_relevant_path', cloud_properties)
          }.to raise_error Bosh::Clouds::CloudError
        end
      end
    end

    describe '#create_vm' do
      let(:network_spec) do
        {
          'default' => {
            'type' => 'dynamic',
            'cloud_properties' => {
              'net_id' => @config.net_id,
            },
          },
        }
      end

      it 'creates a vm with the heavy stemcell id' do
        vm_lifecycle(light_stemcell_id, network_spec)
      end
    end
  end

  describe 'set_disk_metadata' do
    before { @disk_id = cpi.create_disk(2048, {}, nil) }
    after { clean_up_disk(@disk_id) if @disk_id }

    let(:metadata) do
      {
        'id' => 'my-id',
        'deployment' => 'my-deployment',
        'job' => 'my-job',
        'index' => 'my-index',
        'some_key' => 'some_value',
      }
    end

    it 'sets the disk metadata accordingly' do
      disk = openstack.with_openstack(retryable: true) { openstack.volume.volumes.get(@disk_id) }
      expect(disk.metadata).not_to include(metadata)

      cpi.set_disk_metadata(@disk_id, metadata)

      disk = openstack.with_openstack(retryable: true) { openstack.volume.volumes.get(@disk_id) }
      expect(disk.metadata).to include(metadata)
    end
  end

  describe 'resize_disk' do
    before { @disk_id = cpi.create_disk(2048, {}, nil) }
    after { clean_up_disk(@disk_id) if @disk_id }

    it 'resizes the disk' do
      cpi.resize_disk(@disk_id, 4096)

      disk = openstack.with_openstack(retryable: true) { openstack.volume.volumes.get(@disk_id) }
      expect(disk.size).to eq(4)
    end
  end

  describe 'when using load balancer pool' do
    before(:all) do
      skip('No lbaas pool configured') unless @config.lbaas_pool_name
    end

    let(:network_spec) do
      {
        'default' => {
          'type' => 'dynamic',
          'cloud_properties' => {
            'net_id' => @config.net_id,
          },
        },
      }
    end

    let(:resource_pool_spec_with_lbaas_pools) do
      {
        'loadbalancer_pools' => [
          { 'name' => @config.lbaas_pool_name, 'port' => 4443 },
        ],
        'key_name' => @config.default_key_name,
        'availability_zone' => @config.availability_zone,
        'instance_type' => @config.instance_type,
      }
    end

    it 'exercises vm lifecycle' do
      vm_id = nil

      expect {
        vm_id = create_vm(@stemcell_id, network_spec, [], resource_pool_spec_with_lbaas_pools)
      }.to_not raise_error

      expect(vm_id).not_to be_nil

      expect {
        clean_up_vm(vm_id)
      }.to_not raise_error
    end
  end

  describe 'when creating a server in a non-existent availability zone' do
    let(:network_spec) do
      {
        'default' => {
          'type' => 'dynamic',
          'cloud_properties' => {
            'net_id' => @config.net_id,
          },
        },
      }
    end

    let(:resource_pool_spec) do
      {
        'key_name' => @config.default_key_name,
        'availability_zone' => 'fake-availability-zone',
        'instance_type' => @config.instance_type,
      }
    end

    it 'raises an error' do
      expect{
        create_vm(@stemcell_id, network_spec, [], resource_pool_spec)
      }.to raise_error;
    end
  end
end
