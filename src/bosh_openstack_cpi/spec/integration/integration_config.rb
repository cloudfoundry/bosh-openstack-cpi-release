class IntegrationConfig
  attr_reader :logger,
              :auth_url,
              :username,
              :api_key,
              :tenant,
              :project,
              :domain,
              :stemcell_path,
              :net_id,
              :net_id_no_dhcp_1,
              :net_id_no_dhcp_2,
              :volume_type,
              :manual_ip,
              :no_dhcp_manual_ip_1,
              :no_dhcp_manual_ip_2,
              :disable_snapshots,
              :default_key_name,
              :config_drive,
              :ignore_server_az,
              :instance_type,
              :instance_type_with_no_root_disk,
              :availability_zone,
              :region,
              :floating_ip,
              :ca_cert_path,
              :insecure,
              :lbaas_pool_name,
              :test_auto_anti_affinity,
              :allowed_address_pairs

  def initialize(identity_version = :v3)
    if identity_version == :v3
      @auth_url                      = LifecycleHelper.get_config(:auth_url_v3)
      @domain                        = LifecycleHelper.get_config(:domain)
      @username                      = LifecycleHelper.get_config(:username_v3)
      @api_key                       = LifecycleHelper.get_config(:api_key_v3)
      @project                       = LifecycleHelper.get_config(:project)
    else
      @auth_url                      = LifecycleHelper.get_config(:auth_url_v2)
      @username                      = LifecycleHelper.get_config(:username_v2, LifecycleHelper.get_config(:username_v3))
      @api_key                       = LifecycleHelper.get_config(:api_key_v2, LifecycleHelper.get_config(:api_key_v3))
      @tenant                        = LifecycleHelper.get_config(:tenant, LifecycleHelper.get_config(:project))
    end

    @logger                          = Logger.new(STDERR)

    @ca_cert_content                 = LifecycleHelper.get_config(:ca_cert, nil)
    if @ca_cert_content && !@ca_cert_content.empty? && @ca_cert_content != 'null'
      @ca_cert_file = write_ca_cert(logger)
      @ca_cert_path = @ca_cert_file.path
    end
    @insecure = LifecycleHelper.get_config(:insecure, false)
    @connection_options = {
      'connect_timeout'             => LifecycleHelper.get_config(:connect_timeout, '120').to_i,
      'read_timeout'                => LifecycleHelper.get_config(:read_timeout, '120').to_i,
      'write_timeout'               => LifecycleHelper.get_config(:write_timeout, '120').to_i,
      'ssl_verify_peer'             => !@insecure,
    }
    @connection_options['ssl_ca_file'] = @ca_cert_path if @ca_cert_path

    @stemcell_path                   = LifecycleHelper.get_config(:stemcell_path)
    @net_id                          = LifecycleHelper.get_config(:net_id)
    @net_id_no_dhcp_1                = LifecycleHelper.get_config(:net_id_no_dhcp_1)
    @net_id_no_dhcp_2                = LifecycleHelper.get_config(:net_id_no_dhcp_2)
    @volume_type                     = LifecycleHelper.get_config(:volume_type, nil)
    @manual_ip                       = LifecycleHelper.get_config(:manual_ip)
    @no_dhcp_manual_ip_1             = LifecycleHelper.get_config(:no_dhcp_manual_ip_1)
    @no_dhcp_manual_ip_2             = LifecycleHelper.get_config(:no_dhcp_manual_ip_2)
    @disable_snapshots               = LifecycleHelper.get_config(:disable_snapshots, false)
    @default_key_name                = LifecycleHelper.get_config(:default_key_name)
    @config_drive                    = LifecycleHelper.get_config(:config_drive, 'cdrom')
    @ignore_server_az                = LifecycleHelper.get_config(:ignore_server_az, 'false')
    @instance_type                   = LifecycleHelper.get_config(:instance_type, 'm1.small')
    @instance_type_with_no_root_disk = LifecycleHelper.get_config(:flavor_with_no_root_disk)
    @availability_zone               = LifecycleHelper.get_config(:availability_zone, nil)
    @floating_ip                     = LifecycleHelper.get_config(:floating_ip)
    @lbaas_pool_name                 = LifecycleHelper.get_config(:lbaas_pool_name, nil)
    @test_auto_anti_affinity         = LifecycleHelper.get_config(:test_auto_anti_affinity, nil).to_s == 'true'
    @allowed_address_pairs           = LifecycleHelper.get_config(:allowed_address_pairs, nil)
    # some environments may not have this set, and it isn't strictly necessary so don't raise if it isn't set
    @region                          = LifecycleHelper.get_config(:region, nil)
    Bosh::Clouds::Config.configure(OpenStruct.new(logger: @logger, cpi_task_log: nil))
  end

  def create_cpi(boot_from_volume: false, config_drive: nil, human_readable_vm_names: false, use_nova_networking: false, use_dhcp: true, default_volume_type: nil, enable_auto_anti_affinity: false)
    properties = {
      'openstack' => openstack_properties(boot_from_volume, config_drive, human_readable_vm_names, use_nova_networking, use_dhcp, default_volume_type, enable_auto_anti_affinity),
      'registry' => {
        'endpoint' => 'fake',
        'user' => 'fake',
        'password' => 'fake',
      },
    }
    Bosh::OpenStackCloud::Cloud.new(
      properties,
    )
  end

  def create_openstack
    Bosh::OpenStackCloud::Openstack.new(openstack_properties, {}, {})
  end

  def openstack_properties(boot_from_volume = false, config_drive = nil, human_readable_vm_names = false, use_nova_networking = false, use_dhcp = true, default_volume_type = nil, enable_auto_anti_affinity = false)
    properties = {
      'auth_url' => @auth_url,
      'username' => @username,
      'api_key' => @api_key,
      'region' => @region,
      'endpoint_type' => 'publicURL',
      'default_key_name' => @default_key_name,
      'default_security_groups' => %w[default],
      'default_volume_type' => default_volume_type,
      'wait_resource_poll_interval' => 5,
      'boot_from_volume' => boot_from_volume,
      'config_drive' => config_drive,
      'use_dhcp' => use_dhcp,
      'ignore_server_availability_zone' => str_to_bool(@ignore_server_az),
      'human_readable_vm_names' => human_readable_vm_names,
      'use_nova_networking' => use_nova_networking,
      'connection_options' => @connection_options,
      'enable_auto_anti_affinity' => enable_auto_anti_affinity,
    }

    if @domain
      properties['domain'] = @domain
      properties['project'] = @project
    else
      properties['tenant'] = @tenant
    end
    properties
  end

  private

  def write_ca_cert(logger)
    @ca_cert_file = Tempfile.new(['cacert', '.pem'])
    logger.info("cacert.pem file: #{@ca_cert_file.path}")
    File.write(@ca_cert_file.path, @ca_cert_content)
    @ca_cert_file
  end
end
