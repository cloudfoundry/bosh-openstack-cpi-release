require 'spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  let(:default_connection_options) {
    { 'instrumentor' => Bosh::OpenStackCloud::ExconLoggingInstrumentor }
  }

  describe :new do
    let(:cloud_options) { mock_cloud_options }

    before {
      expect(Fog::Compute).to_not receive(:new)
      expect(Fog::Image::OpenStack::V1).to_not receive(:new)
      expect(Fog::Volume::OpenStack::V1).to_not receive(:new)
      expect(Fog::Network).to_not receive(:new)
    }

    describe 'validation' do
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
      subject(:subject) { Bosh::OpenStackCloud::Cloud.new(options) }

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

        it 'raises an error when no project is specified' do
          options['openstack']['domain'] = 'fake_domain'
          expect { subject }.to raise_error(ArgumentError, /Invalid OpenStack cloud properties: #<Membrane::SchemaValidationError: { openstack => { project => Missing key } }/)
        end

        it 'raises an error when no domain is specified' do
          options['openstack']['project'] = 'fake_project'
          expect { subject }.to raise_error(ArgumentError, /Invalid OpenStack cloud properties: #<Membrane::SchemaValidationError: { openstack => { domain => Missing key } }/)
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
  end

  describe :update_agent_settings do
    let(:cloud_options) { mock_cloud_options }
    let(:connection_options) { nil }
    let(:merged_connection_options) { default_connection_options }

    let(:compute) { instance_double('Fog::Compute') }
    before { allow(Fog::Compute).to receive(:new).and_return(compute) }

    let(:image) { instance_double('Fog::Image') }
    before { allow(Fog::Image::OpenStack::V1).to receive(:new).and_return(image) }

    context 'when server has no registry_key tag' do
      it 'uses the server name as key' do
        cpi = Bosh::OpenStackCloud::Cloud.new(cloud_options['properties'])
        server = double('server', id: 'id', name: 'name', metadata: double('metadata'))

        allow(server.metadata).to receive(:get).with(:registry_key).and_return(nil)

        expect(cpi.registry).to receive(:read_settings).with('name')
        expect(cpi.registry).to receive(:update_settings).with('name', anything)

        cpi.update_agent_settings(server) {}
      end
    end

    context 'when server has no registry_key tag' do
      it 'uses the server name as key' do
        cpi = Bosh::OpenStackCloud::Cloud.new(cloud_options['properties'])
        server = double('server', id: 'id', name: 'name', metadata: double('metadata'))

        allow(server.metadata).to receive(:get).with(:registry_key).and_return(double('metadatum', 'value' => 'registry-tag-value'))

        expect(cpi.registry).to receive(:read_settings).with('registry-tag-value')
        expect(cpi.registry).to receive(:update_settings).with('registry-tag-value', anything)

        cpi.update_agent_settings(server) {}
      end
    end
  end

  describe :info do
    let(:cloud_options) { mock_cloud_options }

    it 'returns correct info' do
      cpi = Bosh::OpenStackCloud::Cloud.new(cloud_options['properties'])
      expect(cpi.info).to eq('stemcell_formats' => ['openstack-raw', 'openstack-qcow2', 'openstack-light'])
    end
  end
end
