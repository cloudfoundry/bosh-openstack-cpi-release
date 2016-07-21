require 'integration/spec_helper'
require 'cloud'
require 'logger'
require 'net/http'

describe Bosh::OpenStackCloud::Cloud do
  include Bosh::OpenStackCloud::Helpers

  before(:all) do
    @auth_url                        = LifecycleHelper.get_config(:auth_url_v2)
    @username                        = LifecycleHelper.get_config(:username)
    @api_key                         = LifecycleHelper.get_config(:api_key)
    @tenant                          = LifecycleHelper.get_config(:tenant)
    @stemcell_path                   = LifecycleHelper.get_config(:stemcell_path)
    @default_key_name                = LifecycleHelper.get_config(:default_key_name)
    @ignore_server_az                = LifecycleHelper.get_config(:ignore_server_az, 'false')
  end

  def create_cpi
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
        'boot_from_volume' => false,
        'config_drive' => nil,
        'ignore_server_availability_zone' => str_to_bool(@ignore_server_az),
        'human_readable_vm_names' => false,
        'connection_options' => connection_options(additional_connection_options(@logger))
      },
      'registry' => {
        'endpoint' => 'fake',
        'user' => 'fake',
        'password' => 'fake'
      }
    )
  end

  let(:logger) { Logger.new(STDERR) }

  before do
    delegate = double('delegate', logger: logger, cpi_task_log: nil)
    Bosh::Clouds::Config.configure(delegate)
    allow(Bosh::Clouds::Config).to receive(:logger).and_return(logger)
  end

  describe 'Glance V2 support' do
    let(:cpi_for_stemcell) { create_cpi }

    before do
      expect(cpi_for_stemcell.glance.class.to_s).to start_with('Fog::Image::OpenStack::V2')
    end

    it 'uploads and deletes a stemcell' do
      stemcell_manifest = Psych.load_file(File.join(@stemcell_path, 'stemcell.MF'))
      stemcell_id = cpi_for_stemcell.create_stemcell(File.join(@stemcell_path, 'image'), stemcell_manifest['cloud_properties'])
      expect(stemcell_id).to_not be_nil

      image = cpi_for_stemcell.glance.images.get(stemcell_id)
      expect(image).to_not be_nil
      expect(image.name).to eq("#{stemcell_manifest['cloud_properties']['name']}/#{stemcell_manifest['cloud_properties']['version']}")
      expect(image.visibility).to eq('private')
      expect(image.os_distro).to eq('ubuntu')

      cpi_for_stemcell.delete_stemcell(stemcell_id)
      wait_resource(image, :deleted, :status, true)
    end
  end

  describe 'Glance V1 support' do
    let(:cpi_for_stemcell) { create_cpi }

    before do
      force_image_v1
    end

    it 'uploads and deletes a stemcell' do
      stemcell_manifest = Psych.load_file(File.join(@stemcell_path, 'stemcell.MF'))
      stemcell_id = cpi_for_stemcell.create_stemcell(File.join(@stemcell_path, 'image'), stemcell_manifest['cloud_properties'])
      expect(stemcell_id).to_not be_nil

      image = cpi_for_stemcell.glance.images.get(stemcell_id)
      expect(image).to_not be_nil
      expect(image.name).to eq("#{stemcell_manifest['cloud_properties']['name']}/#{stemcell_manifest['cloud_properties']['version']}")
      expect(image.is_public).to be(false)
      expect(image.properties).to include('os_distro' => 'ubuntu')

      cpi_for_stemcell.delete_stemcell(stemcell_id)
      wait_resource(image, :deleted, :status, true)
    end
  end

  def force_image_v1
    LifecycleHelper.override_root_service_versions(auth_url: @auth_url, port: 9292) do |versions|
      versions.select { |v| v['id'].start_with?('v1.') }
    end

    expect(cpi_for_stemcell.glance.class.to_s).to start_with('Fog::Image::OpenStack::V1')
  end

  def str_to_bool(string)
    if string == 'true'
      true
    else
      false
    end
  end
end
