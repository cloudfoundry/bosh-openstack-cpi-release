require 'spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  let(:default_connection_options) {
    { 'instrumentor' => Bosh::OpenStackCloud::ExconLoggingInstrumentor }
  }
  let(:cpi_api_version) { 2 }

  describe :new do
    let(:cloud_options) { mock_cloud_options }
    let(:cloud_options_stemcell_v2) do
      cloud_options['properties']['openstack']['vm'] = {
        'stemcell' => {
          'api_version' => 2,
        },
      }
      cloud_options
    end

    before {
      expect(Fog::OpenStack::Compute).to_not receive(:new)
      expect(Fog::OpenStack::Image).to_not receive(:new)
      expect(Fog::OpenStack::Volume).to_not receive(:new)
      expect(Fog::Network).to_not receive(:new)
    }

    let(:options) do
      {
        'openstack' => {
          'username' => 'fake-username',
          'api_key' => 'fake-api-key',
        },
        'registry' => {
          'endpoint' => 'fake-registry',
          'user' => 'fake-user',
          'password' => 'fake-password',
        },
      }
    end
    subject { Bosh::OpenStackCloud::Cloud.new(options, cpi_api_version) }

    context 'when keystone V2 API is used' do
      before do
        options['openstack']['auth_url'] = 'http://fake-auth-url/v2.0'
        options['openstack']['tenant'] = 'fake-tenant'
      end

      it 'does not raise an error' do
        expect { subject }.to_not raise_error
      end

      context 'when connection_options are specified' do
        it 'expects connection_options to be a hash' do
          options['openstack']['connection_options'] = { 'any-key' => 'any-value' }

          expect { subject }.to_not raise_error
        end

        it 'raises an error if connection_options is not a Hash' do
          options['openstack']['connection_options'] = 'connection_options'

          expect { subject }.to raise_error(ArgumentError, /Invalid OpenStack cloud properties/)
        end
      end

      context 'when boot_from_volume is specified' do
        it 'expects boot_from_volume to be a boolean' do
          options['openstack']['boot_from_volume'] = true

          expect { subject }.to_not raise_error
        end

        it 'raises an error if boot_from_volume is not a boolean' do
          options['openstack']['boot_from_volume'] = 'boot_from_volume'

          expect { subject }.to raise_error(ArgumentError, /Invalid OpenStack cloud properties/)
        end
      end

      context 'config_drive' do
        it 'accepts cdrom as a value' do
          options['openstack']['config_drive'] = 'cdrom'
          expect { subject }.to_not raise_error
        end

        it 'accepts disk as a value' do
          options['openstack']['config_drive'] = 'disk'
          expect { subject }.to_not raise_error
        end

        it 'accepts nil as a value' do
          options['openstack']['config_drive'] = nil
          expect { subject }.to_not raise_error
        end

        it 'raises an error if config_drive is not cdrom or disk or nil' do
          options['openstack']['config_drive'] = 'incorrect-value'
          expect { subject }.to raise_error(ArgumentError, /Invalid OpenStack cloud properties/)
        end
      end
    end

    context 'when keystone V3 API is used' do
      before do
        options['openstack']['auth_url'] = 'http://127.0.0.1:5000/v3'
      end

      it 'raises an error when no project or project_id is specified' do
        options['openstack']['domain'] = 'fake_domain'
        expect { subject }
          .to raise_error(ArgumentError,
                          Regexp.new('Invalid OpenStack cloud properties: ' \
                                     '#<Membrane::SchemaValidationError: { openstack => { project => Missing key } }'))
      end

      it 'raises an error when no domain is specified' do
        options['openstack']['project'] = 'fake_project'
        expect { subject }
          .to raise_error(ArgumentError,
                          Regexp.new('Invalid OpenStack cloud properties: ' \
                                     '#<Membrane::SchemaValidationError: { openstack => { domain => Missing key } }'))
      end

      context 'when project and domain are specified' do
        before do
          options['openstack']['project'] = 'fake_project'
          options['openstack']['domain'] = 'fake_domain'
        end

        it 'does not raise an error' do
          expect { subject }.to_not raise_error
        end
      end

      context 'when project_id and domain are specified' do
        before do
          options['openstack']['project_id'] = 'fake_project_id'
          options['openstack']['domain'] = 'fake_domain'
        end

        it 'does not raise an error' do
          expect { subject }.to_not raise_error
        end
      end

      context 'when project and user_domain_name and project_domain_name are specified' do
        before do
          options['openstack']['project'] = 'fake_project'
          options['openstack']['user_domain_name'] = 'fake_user_domain'
          options['openstack']['project_domain_name'] = 'fake_project_domain'
        end

        it 'does not raise an error' do
          expect { subject }.to_not raise_error
        end
      end

    end

    context 'when options are empty' do
      let(:options) { Hash.new('options') }

      it 'raises ArgumentError' do
        expect { subject }.to raise_error(ArgumentError, /Invalid OpenStack cloud properties/)
      end
    end

    context 'when options are not a Hash' do
      let(:options) { 'this is a string' }

      it 'raises ArgumentError' do
        expect { subject }.to raise_error(ArgumentError, /Invalid OpenStack cloud properties/)
      end
    end
  end
  describe :update_agent_settings do
    let(:cloud_options) { mock_cloud_options }
    let(:connection_options) { nil }
    let(:merged_connection_options) { default_connection_options }

    let(:compute) { instance_double('Fog::OpenStack::Compute') }
    before { allow(Fog::OpenStack::Compute).to receive(:new).and_return(compute) }

    let(:image) { instance_double('Fog::Image') }
    before { allow(Fog::OpenStack::Image).to receive(:new).and_return(image) }

    context 'when registry is not used' do
      let(:cpi_api_version) { 2 }
      let(:cloud_options_stemcell_v2) do
        cloud_options['properties']['openstack']['vm'] = {
          'stemcell' => {
            'api_version' => 2,
          },
        }
        cloud_options
      end
      it 'does not log anything' do
        cpi = Bosh::OpenStackCloud::Cloud.new(cloud_options_stemcell_v2['properties'], cpi_api_version)
        server = double('server', id: 'id', name: 'name', metadata: double('metadata'))
        allow(server.metadata).to receive(:get).and_return(nil)
        expect(cpi.logger).to_not receive(:info)
      end
    end
  end

  describe :info do
    let(:cloud_options) { mock_cloud_options }

    it 'returns correct info' do
      cpi = Bosh::OpenStackCloud::Cloud.new(cloud_options['properties'], cpi_api_version)
      expect(cpi.info).to eq('api_version' => 2, 'stemcell_formats' => ['openstack-raw', 'openstack-qcow2', 'openstack-light'])
    end
  end

end
