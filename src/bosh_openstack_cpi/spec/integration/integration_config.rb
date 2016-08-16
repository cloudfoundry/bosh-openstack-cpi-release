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
              :region

  def initialize(identity_version=:v3)
    if identity_version == :v3
      @auth_url                      = LifecycleHelper.get_config(:auth_url_v3)
      @domain                        = LifecycleHelper.get_config(:domain)
      @username                      = LifecycleHelper.get_config(:username_v3)
      @api_key                       = LifecycleHelper.get_config(:api_key_v3)
      @project                       = LifecycleHelper.get_config(:project)
    else
      @auth_url                      = LifecycleHelper.get_config(:auth_url_v2)
      @username                      = LifecycleHelper.get_config(:username_v2, LifecycleHelper.get_config(:username))
      @api_key                       = LifecycleHelper.get_config(:api_key_v2, LifecycleHelper.get_config(:api_key))
      @tenant                        = LifecycleHelper.get_config(:tenant, LifecycleHelper.get_config(:project))
    end

    @logger                          = Logger.new(STDERR)
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
    # some environments may not have this set, and it isn't strictly necessary so don't raise if it isn't set
    @region                          = LifecycleHelper.get_config(:region, nil)
    Bosh::Clouds::Config.configure(OpenStruct.new(:logger => @logger, :cpi_task_log => nil))
  end


  def create_cpi(boot_from_value = false, config_drive = nil, human_readable_vm_names = false)
    openstack_properties = {'openstack' => {
        'auth_url' => @auth_url,
        'username' => @username,
        'api_key' => @api_key,
        'region' => @region,
        'endpoint_type' => 'publicURL',
        'default_key_name' => @default_key_name,
        'default_security_groups' => %w(default),
        'wait_resource_poll_interval' => 5,
        'boot_from_volume' => boot_from_value,
        'config_drive' => config_drive,
        'ignore_server_availability_zone' => str_to_bool(@ignore_server_az),
        'human_readable_vm_names' => human_readable_vm_names,
        'connection_options' => connection_options(additional_connection_options(@logger))
    },
            'registry' => {
                'endpoint' => 'fake',
                'user' => 'fake',
                'password' => 'fake'
            }}

    if @domain
      openstack_properties['openstack']['domain']  = @domain
      openstack_properties['openstack']['project'] = @project
    else
      openstack_properties['openstack']['tenant'] = @tenant
    end

    Bosh::OpenStackCloud::Cloud.new(
        openstack_properties
    )
  end

end