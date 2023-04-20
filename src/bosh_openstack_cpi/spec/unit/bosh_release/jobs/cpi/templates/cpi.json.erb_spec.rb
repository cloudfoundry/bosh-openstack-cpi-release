require 'spec_helper'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'cpi.json.erb' do
  let(:cpi_v1_json) { JSON.parse(template.render(manifest_cpi_v1)) }
  let(:cpi_v2_json) { JSON.parse(template.render(manifest_cpi_v2)) }

  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '../../../../../../../../')) }
  let(:job) { release.job('openstack_cpi') }
  let(:template) { job.template('config/cpi.json') }

  let(:manifest_cpi_v1) do
    {
      'openstack' => {
        'auth_url' => 'openstack.auth_url',
        'username' => 'openstack.username',
        'api_key' => 'openstack.api_key',
        'tenant' => 'openstack.tenant',
        'default_key_name' => 'openstack.default_key_name',
        'default_security_groups' => 'openstack.default_security_groups',
        'wait_resource_poll_interval' => 'openstack.wait_resource_poll_interval',
        'human_readable_vm_names' => false,
        'ignore_server_availability_zone' => 'openstack.ignore_server_availability_zone',
      },
      'ntp' => [],
      'registry' => {
        'username' => 'registry.username',
        'password' => 'registry.password',
        'host' => 'registry.host',
        'endpoint' => 'http://registry.host:25777',
      },
      'nats' => {
        'address' => 'nats_address.example.com',
        'password' => 'nats-password',
        'user' => 'nats-user',
      },
    }
  end

  let(:manifest_cpi_v2) do
    {
      'openstack' => {
        'auth_url' => 'openstack.auth_url',
        'username' => 'openstack.username',
        'api_key' => 'openstack.api_key',
        'tenant' => 'openstack.tenant',
        'default_key_name' => 'openstack.default_key_name',
        'default_security_groups' => 'openstack.default_security_groups',
        'wait_resource_poll_interval' => 'openstack.wait_resource_poll_interval',
        'human_readable_vm_names' => false,
        'ignore_server_availability_zone' => 'openstack.ignore_server_availability_zone',
      },
    }
  end

  it 'is able to render the erb given most basic manifest properties' do
    expect(cpi_v2_json).to eq(
      'cloud' => {
        'plugin' => 'openstack',
        'properties' => {
          'openstack' => {
            'api_key' => 'openstack.api_key',
            'auth_url' => 'openstack.auth_url',
            'boot_from_volume' => false,
            'default_key_name' => 'openstack.default_key_name',
            'default_security_groups' => 'openstack.default_security_groups',
            'endpoint_type' => 'publicURL',
            'ignore_server_availability_zone' => 'openstack.ignore_server_availability_zone',
            'state_timeout' => 300,
            'stemcell_public_visibility' => false,
            'tenant' => 'openstack.tenant',
            'use_dhcp' => true,
            'username' => 'openstack.username',
            'wait_resource_poll_interval' => 'openstack.wait_resource_poll_interval',
            'human_readable_vm_names' => false,
            'use_nova_networking' => false,
            'default_volume_type' => nil,
          },
        },
      },
    )
  end

  context 'when using human readable VM names' do
    it 'template rendering succeeds' do
      manifest_cpi_v2['openstack']['human_readable_vm_names'] = true

      expect(cpi_v2_json['cloud']['properties']['openstack']['human_readable_vm_names']).to be true
    end
  end

  context 'when registry is configured for bosh-init' do
    it 'concatinates host and port as registry endpoint and template rendering succeeds' do
      manifest_cpi_v2['registry'] = {}
      manifest_cpi_v2['registry']['username'] = 'registry.username'
      manifest_cpi_v2['registry']['password'] = 'registry.password'
      manifest_cpi_v2['registry']['host'] = '127.0.0.1'
      manifest_cpi_v2['registry']['port'] = 6901

      expect(cpi_v2_json['cloud']['properties']['registry']['endpoint']).to eq('http://127.0.0.1:6901')
    end

    it 'it raises an error if some registry properties are missing' do
      manifest_cpi_v2['registry'] = {}
      manifest_cpi_v2['registry']['username'] = ''
      manifest_cpi_v2['registry']['password'] = ''
      manifest_cpi_v2['registry']['endpoint'] = 'http://registry.host:25777'
      manifest_cpi_v2['registry']['port'] = 6901

      expect { cpi_v2_json }.to raise_error Bosh::Template::UnknownProperty
    end

    it 'it does not raise an error if no registry properties are set' do
      manifest_cpi_v2['registry'] = {}

      expect { cpi_v2_json }.to_not raise_error
      expect(cpi_v2_json['cloud']['properties']['registry']).to eq(nil)
    end
  end

  describe 'when anti-affinity is configured' do
    [false, true].each do |prop|
      context "when anti-affinity is set to #{prop}" do
        it 'errors to inform the user this is no longer supported' do
          manifest_cpi_v1['openstack']['enable_auto_anti_affinity'] = prop

          expect { cpi_v1_json }.to raise_error RuntimeError,
            "Property 'enable_auto_anti_affinity' is no longer supported. Please remove it from your configuration."
        end
      end
    end
  end

  context 'when cpi api v1' do
    it 'is able to render the erb given most basic manifest properties' do
      expect(cpi_v1_json).to eq(
        'cloud' => {
          'plugin' => 'openstack',
          'properties' => {
            'agent' => {
              'mbus' => 'nats://nats-user:nats-password@nats_address.example.com:4222',
              'ntp' => [],
            },
            'openstack' => {
              'api_key' => 'openstack.api_key',
              'auth_url' => 'openstack.auth_url',
              'boot_from_volume' => false,
              'default_key_name' => 'openstack.default_key_name',
              'default_security_groups' => 'openstack.default_security_groups',
              'endpoint_type' => 'publicURL',
              'ignore_server_availability_zone' => 'openstack.ignore_server_availability_zone',
              'state_timeout' => 300,
              'stemcell_public_visibility' => false,
              'tenant' => 'openstack.tenant',
              'use_dhcp' => true,
              'username' => 'openstack.username',
              'wait_resource_poll_interval' => 'openstack.wait_resource_poll_interval',
              'human_readable_vm_names' => false,
              'use_nova_networking' => false,
              'default_volume_type' => nil,
            },
            'registry' => {
              'address' => 'registry.host',
              'endpoint' => 'http://registry.host:25777',
              'password' => 'registry.password',
              'user' => 'registry.username',
            },
          }
        }
      )
    end
  end
end
