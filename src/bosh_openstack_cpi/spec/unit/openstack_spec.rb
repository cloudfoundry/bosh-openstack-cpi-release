require 'spec_helper'

describe Bosh::OpenStackCloud::Openstack do
  let(:openstack_options_v2) { mock_cloud_options['properties']['openstack'] }
  let(:openstack_options_v3) { mock_cloud_options(3)['properties']['openstack'] }
  let(:openstack_options) { openstack_options_v2 }
  subject(:subject) { Bosh::OpenStackCloud::Openstack.new(openstack_options) }

  describe 'is_v3' do
    it 'should identify keystone v3 URIs' do
      expect(Bosh::OpenStackCloud::Openstack.is_v3('http://fake-auth-url/v3')).to be_truthy
    end

    it 'should identify keystone v2 URIs' do
      expect(Bosh::OpenStackCloud::Openstack.is_v3('http://fake-auth-url/v2.0')).to be_falsey
    end
  end

  describe :new do
    context 'when auth_url does not include tokens' do
      context 'when auth_url is v2' do
        it 'should update the auth_url with tokens' do
          expect(subject.auth_url).to eq('http://127.0.0.1:5000/v2.0/tokens')
        end
      end

      context 'when auth_url is v3' do
        let(:openstack_options) { openstack_options_v3 }

        it 'should update the auth_url with tokens' do
          expect(subject.auth_url).to eq('http://127.0.0.1:5000/v3/auth/tokens')
        end
      end
    end

    context 'when the full auth_url was specified' do
      context 'when auth_url is v2' do
        before do
          openstack_options_v2['auth_url'] = 'http://fake-auth-url/v2.0/tokens'
        end

        it 'does not change auth_url option' do
          expect(subject.auth_url).to eq('http://fake-auth-url/v2.0/tokens')
        end
      end

      context 'when auth_url is v3' do

        let(:openstack_options) { openstack_options_v3 }
        before do
          openstack_options_v3['auth_url'] = 'http://fake-auth-url/v3/auth/tokens'
        end

        it 'does not change auth_url option' do
          expect(subject.auth_url).to eq('http://fake-auth-url/v3/auth/tokens')
        end
      end

      context 'and it ends with a slash' do
        before do
          openstack_options_v2['auth_url'] = 'http://fake-auth-url/v2.0/'
        end

        it 'removes the trailing slash' do
          expect(subject.auth_url).to eq('http://fake-auth-url/v2.0/tokens')
        end
      end
    end

    context 'excon instrumentor' do
      context 'default instrumentor' do
        it 'set the default instrumentor' do
          openstack = Bosh::OpenStackCloud::Openstack.new(openstack_options)

          expect(openstack.params[:connection_options]['instrumentor']).to eq(Bosh::OpenStackCloud::ExconLoggingInstrumentor)
        end
      end

      context 'no instrumentor' do
        it 'set the default instrumentor' do
          openstack = Bosh::OpenStackCloud::Openstack.new(openstack_options, {}, {})

          expect(openstack.params[:connection_options].has_key?('instrumentor')).to be(false)
        end
      end
    end
  end

  describe :use_nova_networking? do
    context 'when the manifest contains `use_nova_networking=true`' do
      let(:openstack_options_with_nova) { openstack_options_v3['use_nova_networking'] = true; openstack_options_v3 }
      let(:openstack_options) { openstack_options_with_nova }
      it 'returns true' do
        expect(subject.use_nova_networking?).to eq(true)
      end
    end

    context 'when the manifest contains `use_nova_networking=false`' do
      let(:openstack_options_with_nova) { openstack_options_v3['use_nova_networking'] = false; openstack_options_v3 }
      let(:openstack_options) { openstack_options_with_nova }
      it 'returns false' do
        expect(subject.use_nova_networking?).to eq(false)
      end
    end

    context 'when the manifest does not contain `use_nova_networking`' do
      let(:openstack_options) { openstack_options_v3 }
      it 'returns false' do
        expect(subject.use_nova_networking?).to eq(false)
      end
    end
  end

  context 'when the service is not available' do
    describe 'Network' do
      it 'raises a CloudError exception if cannot connect to the service API' do
        allow(Fog::Network).to receive(:new).and_raise(Fog::Errors::NotFound, 'Not found message')
        expect {
          Bosh::OpenStackCloud::Openstack.new(openstack_options).network
        }.to raise_error(Bosh::Clouds::CloudError,
            'Unable to connect to the OpenStack Network Service API: Not found message. Check task debug log for details.')
      end
    end
  end

  [{clazz: Fog::Compute, name: 'Compute', method_name: :compute},
      {clazz: Fog::Image::OpenStack::V2, name: 'Image', method_name: :image},
      {clazz: Fog::Volume::OpenStack::V2, name: 'Volume', method_name: :volume},
      {clazz: Fog::Network, name: 'Network', method_name: :network}
  ].each do |fog|
    describe "#{fog[:name]}" do

      let(:retry_options_overwrites){ {
        sleep: 0
      } }

      context 'when the service returns Unauthorized' do
        it 'raises a CloudError exception if cannot connect to the service API 5 times' do
          allow(fog[:clazz]).to receive(:new).and_raise(Excon::Errors::Unauthorized, 'Unauthorized')
          expect {
            Bosh::OpenStackCloud::Openstack.new(openstack_options, retry_options_overwrites).send(fog[:method_name])
          }.to raise_error(Bosh::Clouds::CloudError,
              "Unable to connect to the OpenStack #{fog[:name]} Service API: Unauthorized. Check task debug log for details.")
        end
      end

      context 'when the backend call raises a SocketError' do
        let(:socket_error) { Excon::Errors::SocketError.new(SocketError.new('getaddrinfo: nodename nor servname provided, or not known')) }
        let(:expected_error_message) { "Unable to connect to the OpenStack Keystone API #{openstack_options['auth_url']}/tokens\ngetaddrinfo: nodename nor servname provided, or not known (SocketError)" }

        it 'raises a CloudError exception enriched with the targeted OpenStack KeyStone API url for service API' do
          allow(fog[:clazz]).to receive(:new).and_raise(socket_error)

          expect {
            Bosh::OpenStackCloud::Openstack.new(openstack_options, retry_options_overwrites).send(fog[:method_name])
          }.to raise_error(Bosh::Clouds::CloudError, expected_error_message)
        end
      end

      context 'with connection options' do
        let(:connection_options) { {'ssl_verify_peer' => false} }
        let(:default_connection_options) {
          {"instrumentor" => Bosh::OpenStackCloud::ExconLoggingInstrumentor}
        }
        let(:merged_connection_options) {
          default_connection_options.merge(connection_options)
        }

        it 'should add optional options to the Fog connection' do
          openstack_options['connection_options'] = connection_options

          allow(fog[:clazz]).to receive(:new).and_return(instance_double(fog[:clazz]))
          Bosh::OpenStackCloud::Openstack.new(openstack_options).send(fog[:method_name])

          expect(fog[:clazz]).to have_received(:new).with(hash_including(connection_options: merged_connection_options))
        end
      end

      context 'when keystone V3 API is used' do
        let(:openstack_options) { openstack_options_v3 }
        it 'should add optional options to the Fog connection' do
          allow(fog[:clazz]).to receive(:new).and_return(instance_double(fog[:clazz]))
          Bosh::OpenStackCloud::Openstack.new(openstack_options).send(fog[:method_name])

          expect(fog[:clazz]).to have_received(:new).with(hash_including(openstack_project_name: 'admin'))
          expect(fog[:clazz]).to have_received(:new).with(hash_including(openstack_domain_name: 'some_domain'))
        end
      end

      context 'when keystone V2 API is used' do

        it 'should add optional options to the Fog connection' do
          allow(fog[:clazz]).to receive(:new).and_return(instance_double(fog[:clazz]))
          Bosh::OpenStackCloud::Openstack.new(openstack_options).send(fog[:method_name])

          expect(fog[:clazz]).to have_received(:new).with(hash_including(openstack_tenant: 'admin'))
        end
      end

      context 'when last retry succeeds' do

        before do
          retry_count = 0
          allow(fog[:clazz]).to receive(:new) do
            retry_count += 1
            if retry_count < Bosh::OpenStackCloud::Cloud::CONNECT_RETRY_COUNT
              raise Excon::Errors::GatewayTimeout.new('Gateway Timeout')
            end
            instance_double(fog[:clazz])
          end
        end

        it 'does not raise a GatewayTimeout error' do

          expect {
            Bosh::OpenStackCloud::Openstack.new(openstack_options)
          }.to_not raise_error
        end
      end

      context 'when used multiple times' do

        it 'creates the connection lazy and caches it' do
          expect(fog[:clazz]).to receive(:new).once.and_return(instance_double(fog[:clazz]))
          openstack = Bosh::OpenStackCloud::Openstack.new(openstack_options)

          fog_class_1st_call = openstack.send(fog[:method_name])
          fog_class_2nd_call = openstack.send(fog[:method_name])

          expect(fog_class_1st_call).to eq fog_class_2nd_call
        end
      end
    end
  end


  describe 'wait_resource' do
    let(:resource) { double('resource', id: 'foobar', reload: {}) }
    before { allow(resource).to receive(:status).and_return(:start, :stop) }
    before { allow(subject).to receive(:sleep) }

    it 'does not raise if one of the target states is reached' do
      expect {
        subject.wait_resource(resource, [:stop, :deleted], :status, false)
      }.to_not raise_error
    end

    it 'waits for configured amount of time' do
      expect(subject).to receive(:sleep).with(3)

      subject.wait_resource(resource, [:stop, :deleted], :status, false)
    end

    context 'when the resource status never changes' do
      it 'times out' do
        start_time = Time.now
        timeout_time = start_time + subject.state_timeout + 1
        Timecop.freeze(start_time)

        allow(resource).to receive(:status) do
          Timecop.freeze(timeout_time)
          :start
        end

        expect {
          subject.wait_resource(resource, :stop, :status, false)
        }.to raise_error Bosh::Clouds::CloudError, /Timed out/
      end
    end

    context 'when the resource status is error' do
      before { allow(resource).to receive(:status).and_return(:error) }
      context 'when no additional fault is provided by OpenStack' do
        before { allow(resource).to receive(:fault).and_return(nil) }

        it 'raises Bosh::Clouds::CloudError' do
          expect {
            subject.wait_resource(resource, :stop, :status, false)
          }.to raise_error Bosh::Clouds::CloudError, /state is error/
        end
      end

      context 'when no additional fault supported by resource' do
        it 'raises Bosh::Clouds::CloudError' do
          expect {
            subject.wait_resource(resource, :stop, :status, false)
          }.to raise_error Bosh::Clouds::CloudError, /state is error/
        end
      end

      context 'when additional fault is provided by OpenStack' do
        let(:resource) { double('resource', id: 'foobar', reload: {}, fault: {'message' => 'fault message ', 'details' => 'fault details'}) }

        it 'raises Bosh::Clouds::CloudError' do
          expect {
            subject.wait_resource(resource, :stop, :status, false)
          }.to raise_error Bosh::Clouds::CloudError, /state is error, expected stop\nfault message fault details/
        end
      end
    end

    context 'when the resource status is failed' do
      before { allow(resource).to receive(:status).and_return(:failed) }
      context 'when no additional fault is provided by OpenStack' do
        before { allow(resource).to receive(:fault).and_return(nil) }

        it 'raises Bosh::Clouds::CloudError' do
          expect {
            subject.wait_resource(resource, :stop, :status, false)
          }.to raise_error Bosh::Clouds::CloudError, /state is failed/
        end
      end

      context 'when no additional fault supported by resource' do
        it 'raises Bosh::Clouds::CloudError' do
          expect {
            subject.wait_resource(resource, :stop, :status, false)
          }.to raise_error Bosh::Clouds::CloudError, /state is failed/
        end
      end

      context 'when additional fault is provided by OpenStack' do
        let(:resource) { double('resource', id: 'foobar', reload: {}, fault: {'message' => 'fault message ', 'details' => 'fault details'}) }

        it 'raises Bosh::Clouds::CloudError' do
          expect {
            subject.wait_resource(resource, :stop, :status, false)
          }.to raise_error Bosh::Clouds::CloudError, /state is failed, expected stop\nfault message fault details/
        end
      end
    end

    context 'when the resource status is killed' do
      before { allow(resource).to receive(:status).and_return(:killed) }
      context 'when no additional fault is provided by OpenStack' do
        before { allow(resource).to receive(:fault).and_return(nil) }

        it 'raises Bosh::Clouds::CloudError' do
          expect {
            subject.wait_resource(resource, :stop, :status, false)
          }.to raise_error Bosh::Clouds::CloudError, /state is killed/
        end
      end

      context 'when no additional fault supported by resource' do
        it 'raises Bosh::Clouds::CloudError' do
          expect {
            subject.wait_resource(resource, :stop, :status, false)
          }.to raise_error Bosh::Clouds::CloudError, /state is killed/
        end
      end

      context 'when additional fault is provided by OpenStack' do
        let(:resource) { double('resource', id: 'foobar', reload: {}, fault: {'message' => 'fault message ', 'details' => 'fault details'}) }

        it 'raises Bosh::Clouds::CloudError' do
          expect {
            subject.wait_resource(resource, :stop, :status, false)
          }.to raise_error Bosh::Clouds::CloudError, /state is killed, expected stop\nfault message fault details/
        end
      end
    end

    context 'when the resource is not found' do
      before { allow(resource).to receive(:reload).and_return(nil) }

      it 'should raise Bosh::Clouds::CloudError if resource not found' do
        expect {
          subject.wait_resource(resource, :deleted, :status, false)
        }.to raise_error Bosh::Clouds::CloudError, /Resource not found/
      end

      context 'when the resource does not need to be found' do
        it 'does not raise' do
          expect { subject.wait_resource(resource, :deleted, :status, true) }.not_to raise_error
        end
      end
    end
  end
end
