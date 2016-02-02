require 'spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  let(:default_connection_options) {
    {"instrumentor" => Bosh::OpenStackCloud::ExconLoggingInstrumentor}
  }

  describe :new do
    let(:cloud_options) { mock_cloud_options }
    let(:connection_options) { nil }
    let(:merged_connection_options) { default_connection_options }

    let(:compute) { instance_double('Fog::Compute') }
    before { allow(Fog::Compute).to receive(:new).and_return(compute) }

    let(:image) { instance_double('Fog::Image') }
    before { allow(Fog::Image).to receive(:new).and_return(image) }

    describe 'validation' do
      let(:options) do
        {
          'openstack' => {
            'username' => 'fake-username',
            'api_key' => 'fake-api-key'
          },
          'registry' => {
            'endpoint' => 'fake-registry',
            'user' => 'fake-user',
            'password' => 'fake-password',
          }
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

        it 'to be v2' do
          expect(subject.is_v3).to be nil
        end

        it 'auth_url updated with tokens' do
          expect(subject.auth_url).to eq('http://fake-auth-url/v2.0/tokens')
        end

        context 'when the full auth_url was specified' do
          before do
            options['openstack']['auth_url'] = 'http://fake-auth-url/v2.0/tokens'
          end

          it 'to be v2' do
            expect(subject.is_v3).to be nil
          end

          it 'does not change auth_url option' do
            expect(subject.auth_url).to eq('http://fake-auth-url/v2.0/tokens')
          end

        end

        context 'when connection_options are specified' do
          it 'expects connection_options to be a hash' do
            options['openstack']['connection_options'] = {'any-key' => 'any-value'}

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

          context 'when api url is specified' do
            before do
              options['openstack']['auth_url'] = 'http://127.0.0.1:5000/v3'
            end

            it 'to be v3' do
              expect(subject.is_v3).to_not be nil
            end

            it 'auth_url updated with auth/tokens' do
              expect(subject.auth_url).to eq('http://127.0.0.1:5000/v3/auth/tokens')
            end
          end

          context 'when the full auth_url was specified' do
            before do
              options['openstack']['auth_url'] = 'http://127.0.0.1:5000/v3/auth/tokens'
            end

            it 'to be v3' do
              expect(subject.is_v3).to_not be nil
            end

            it 'does not change auth_url option' do
              expect(subject.is_v3).to_not be nil
            end

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

    it 'creates a Fog connection' do
      cloud = Bosh::OpenStackCloud::Cloud.new(cloud_options['properties'])

      expect(cloud.openstack).to eql(compute)
      expect(cloud.glance).to eql(image)
    end

    it 'retries connecting if a GatewayTimeout error is returned by any OpenStack API endpoint' do
      retry_count = 0
      allow(Fog::Compute).to receive(:new) do
        retry_count += 1
        if retry_count < Bosh::OpenStackCloud::Cloud::CONNECT_RETRY_COUNT
          raise Excon::Errors::GatewayTimeout.new('Gateway Timeout')
        end
        instance_double(Fog::Compute)
      end

      allow(Fog::Image).to receive(:new).and_return(instance_double(Fog::Image))
      allow(Fog::Volume).to receive(:new).and_return(instance_double(Fog::Volume))
      expect {
        Bosh::OpenStackCloud::Cloud.new(cloud_options['properties'])
      }.to_not raise_error

      retry_count = 0
      allow(Fog::Image).to receive(:new) do
        retry_count += 1
        if retry_count < Bosh::OpenStackCloud::Cloud::CONNECT_RETRY_COUNT
          raise Excon::Errors::GatewayTimeout.new('Gateway Timeout')
        end
        instance_double(Fog::Image)
      end

      allow(Fog::Compute).to receive(:new).and_return(instance_double(Fog::Compute))
      allow(Fog::Volume).to receive(:new).and_return(instance_double(Fog::Volume))
      expect {
        Bosh::OpenStackCloud::Cloud.new(cloud_options['properties'])
      }.to_not raise_error

      retry_count = 0
      allow(Fog::Volume).to receive(:new) do
        retry_count += 1
        if retry_count < Bosh::OpenStackCloud::Cloud::CONNECT_RETRY_COUNT
          raise Excon::Errors::GatewayTimeout.new('Gateway Timeout')
        end
        instance_double(Fog::Volume)
      end

      allow(Fog::Compute).to receive(:new).and_return(instance_double(Fog::Compute))
      allow(Fog::Image).to receive(:new).and_return(instance_double(Fog::Image))
      expect {
        Bosh::OpenStackCloud::Cloud.new(cloud_options['properties'])
      }.to_not raise_error
    end

    it 'raises a CloudError exception if cannot connect to the OpenStack Compute API 5 times' do
      allow(Fog::Compute).to receive(:new).and_raise(Excon::Errors::Unauthorized, 'Unauthorized')
      allow(Fog::Image).to receive(:new).and_return(instance_double(Fog::Image))
      allow(Fog::Volume).to receive(:new).and_return(instance_double(Fog::Volume))
      expect {
        Bosh::OpenStackCloud::Cloud.new(cloud_options['properties'])
      }.to raise_error(Bosh::Clouds::CloudError,
        'Unable to connect to the OpenStack Compute API. Check task debug log for details.')
    end

    it 'raises a CloudError exception if cannot connect to the OpenStack Image Service API 5 times' do
      allow(Fog::Compute).to receive(:new).and_return(instance_double(Fog::Compute))
      allow(Fog::Image).to receive(:new).and_raise(Excon::Errors::Unauthorized, 'Unauthorized')
      allow(Fog::Volume).to receive(:new).and_return(instance_double(Fog::Volume))
      expect {
        Bosh::OpenStackCloud::Cloud.new(cloud_options['properties'])
      }.to raise_error(Bosh::Clouds::CloudError,
        'Unable to connect to the OpenStack Image Service API. Check task debug log for details.')
    end

    context 'when receiving a SocketError from Openstack' do
      let(:socket_error) { Excon::Errors::SocketError.new(SocketError.new('getaddrinfo: nodename nor servname provided, or not known')) }
      let(:expected_error_message) { "Unable to connect to the OpenStack Keystone API #{cloud_options['properties']['openstack']['auth_url']}/tokens\ngetaddrinfo: nodename nor servname provided, or not known (SocketError)" }

      it 'raises a CloudError exception enriched with the targeted OpenStack KeyStone API url for Compute API' do
        allow(Fog::Compute).to receive(:new).and_raise(socket_error)

        expect {
          Bosh::OpenStackCloud::Cloud.new(cloud_options['properties'])
        }.to raise_error(Bosh::Clouds::CloudError, expected_error_message)
      end

      it 'raises a CloudError exception enriched with the targeted OpenStack KeyStone API url for Image API' do
        allow(Fog::Compute).to receive(:new).and_return(instance_double(Fog::Compute))
        allow(Fog::Image).to receive(:new).and_raise(socket_error)

        expect {
          Bosh::OpenStackCloud::Cloud.new(cloud_options['properties'])
        }.to raise_error(Bosh::Clouds::CloudError, expected_error_message)
      end
    end

    context 'with connection options' do
      let(:connection_options) { {'ssl_verify_peer' => false} }
      let(:merged_connection_options) {
        default_connection_options.merge(connection_options)
      }

      it 'should add optional options to the Fog connection' do
        cloud_options['properties']['openstack']['connection_options'] = connection_options
        allow(Fog::Compute).to receive(:new).and_return(compute)
        allow(Fog::Image).to receive(:new).and_return(image)
        Bosh::OpenStackCloud::Cloud.new(cloud_options['properties'])

        expect(Fog::Compute).to have_received(:new).with(hash_including(connection_options: merged_connection_options))
        expect(Fog::Image).to have_received(:new).with(hash_including(connection_options: merged_connection_options))
      end
    end

    context 'when keystone V3 API is used' do
      let(:volume) { double('Fog::Volume') }
      let(:volumes) { double('volumes') }
      let(:new_volume) { double('new_volume') }
      let(:cloud_options) { mock_cloud_options(3) }
      before do
        allow(Fog::Volume).to receive(:new).and_return(volume)
        allow(new_volume).to receive(:id).and_return(1)
        allow(volumes).to receive(:create).and_return(new_volume)
        allow(volume).to receive(:volumes).and_return(volumes)
      end

      before do
        allow(Fog::Compute).to receive(:new).and_return(compute)
        allow(Fog::Image).to receive(:new).and_return(image)
      end

      it "should pass 'domain' and 'project' as options to the Fog::Compute connection" do
        Bosh::OpenStackCloud::Cloud.new(cloud_options['properties'])
        expect(Fog::Compute).to have_received(:new).with(hash_including(openstack_project_name: 'admin'))
        expect(Fog::Compute).to have_received(:new).with(hash_including(openstack_domain_name: 'some_domain'))
      end

      it "should pass 'domain' and 'project' as options to the Fog::Image connection" do
        Bosh::OpenStackCloud::Cloud.new(cloud_options['properties'])
        expect(Fog::Image).to have_received(:new).with(hash_including(openstack_project_name: 'admin'))
        expect(Fog::Image).to have_received(:new).with(hash_including(openstack_domain_name: 'some_domain'))
      end

      it "should pass 'domain' and 'project' as options to the Fog::Volume connection" do
        cpi = Bosh::OpenStackCloud::Cloud.new(cloud_options['properties'])
        allow(cpi).to receive(:wait_resource).with(any_args).and_return(true)
        cpi.create_disk(1024, {})
        expect(Fog::Volume).to have_received(:new).with(hash_including(openstack_project_name: 'admin'))
        expect(Fog::Volume).to have_received(:new).with(hash_including(openstack_domain_name: 'some_domain'))
      end
    end
  end
end

