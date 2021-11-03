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
      'blobstore' => {
        'provider' => 'local',
        'path' => 'blobstore-local-path',
      },
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

  context 'when blobstore is configured for v2' do
    it 'template rendering succeeds' do
      manifest_cpi_v2['blobstore'] = {
        'provider' => 'local',
        'path' => 'blobstore-local-path',
      }

      expect(cpi_v2_json['cloud']['properties']['agent']['blobstore']['provider']).to eq('local')
    end
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
    let(:rendered_blobstore) { cpi_v1_json['cloud']['properties']['agent']['blobstore'] }

    it 'is able to render the erb given most basic manifest properties' do
      expect(cpi_v1_json).to eq(
        'cloud' => {
          'plugin' => 'openstack',
          'properties' => {
            'agent' => {
              'blobstore' => {
                'options' => {
                  'blobstore_path' => 'blobstore-local-path',
                },
                'provider' => 'local',
              },
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
          },
        },
      )
    end

    context 'when using an s3 blobstore' do
      context 'when provided a minimal configuration' do
        before do
          manifest_cpi_v1['blobstore'].merge!(
            'provider' => 's3',
            'bucket_name' => 'my_bucket',
            'access_key_id' => 'blobstore-access-key-id',
            'secret_access_key' => 'blobstore-secret-access-key',
          )
        end

        it 'renders the s3 provider section with the correct defaults' do
          expect(rendered_blobstore).to eq(
            'provider' => 's3',
            'options' => {
              'bucket_name' => 'my_bucket',
              'access_key_id' => 'blobstore-access-key-id',
              'secret_access_key' => 'blobstore-secret-access-key',
              'use_ssl' => true,
              'ssl_verify_peer' => true,
              'port' => 443,
            },
          )
        end
      end

      context 'when provided a maximal configuration' do
        before do
          manifest_cpi_v1['blobstore'].merge!(
            'provider' => 's3',
            'bucket_name' => 'my_bucket',
            'access_key_id' => 'blobstore-access-key-id',
            'secret_access_key' => 'blobstore-secret-access-key',
            's3_region' => 'blobstore-region',
            'use_ssl' => false,
            's3_port' => 21,
            'host' => 'blobstore-host',
            'ssl_verify_peer' => true,
            's3_signature_version' => '11',
          )
        end

        it 'renders the s3 provider section correctly' do
          expect(rendered_blobstore).to eq(
            'provider' => 's3',
            'options' => {
              'bucket_name' => 'my_bucket',
              'access_key_id' => 'blobstore-access-key-id',
              'secret_access_key' => 'blobstore-secret-access-key',
              'region' => 'blobstore-region',
              'use_ssl' => false,
              'host' => 'blobstore-host',
              'port' => 21,
              'ssl_verify_peer' => true,
              'signature_version' => '11',
            },
          )
        end

        it 'prefers the agent properties when they are both included' do
          manifest_cpi_v1['agent'] = {
            'blobstore' => {
              'access_key_id' => 'agent_access_key_id',
              'secret_access_key' => 'agent_secret_access_key',
              's3_region' => 'agent-region',
              'use_ssl' => true,
              's3_port' => 42,
              'host' => 'agent-host',
              'ssl_verify_peer' => true,
              's3_signature_version' => '99',
            },
          }

          manifest_cpi_v1['blobstore'].merge!(
            'access_key_id' => 'blobstore_access_key_id',
            'secret_access_key' => 'blobstore_secret_access_key',
            's3_region' => 'blobstore-region',
            'use_ssl' => false,
            's3_port' => 21,
            'host' => 'blobstore-host',
            'ssl_verify_peer' => false,
            's3_signature_version' => '11',
          )

          expect(rendered_blobstore['options']['access_key_id']).to eq('agent_access_key_id')
          expect(rendered_blobstore['options']['secret_access_key']).to eq('agent_secret_access_key')
          expect(rendered_blobstore['options']['region']).to eq('agent-region')
          expect(rendered_blobstore['options']['use_ssl']).to be true
          expect(rendered_blobstore['options']['port']).to eq(42)
          expect(rendered_blobstore['options']['host']).to eq('agent-host')
          expect(rendered_blobstore['options']['ssl_verify_peer']).to be true
          expect(rendered_blobstore['options']['signature_version']).to eq('99')
        end
      end
    end

    context 'when using a dav blobstore' do
      before do
        manifest_cpi_v1['blobstore'] = {
          'provider' => 'dav',
          'address' => 'blobstore-address.example.com',
          'port' => '25250',
          'agent' => {
            'user' => 'agent',
            'password' => 'agent-password'
          }
        }
      end

      it 'renders the agent blobstore section with the correct values' do
        expect(rendered_blobstore).to eq(
          'provider' => 'dav',
          'options' => {
            'endpoint' => 'http://blobstore-address.example.com:25250',
            'user' => 'agent',
            'password' => 'agent-password'
          }
        )
      end

      context 'when enabling signed URLs' do
        before do
          manifest_cpi_v1['blobstore']['agent'].delete('user')
          manifest_cpi_v1['blobstore']['agent'].delete('password')
        end

        it 'does not render agent user/password for accessing blobstore' do
          expect(rendered_blobstore['options']['user']).to be_nil
          expect(rendered_blobstore['options']['password']).to be_nil
        end
      end
    end
  end
end
