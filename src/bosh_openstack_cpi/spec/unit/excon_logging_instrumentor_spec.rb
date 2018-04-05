require 'spec_helper'

describe Bosh::OpenStackCloud::ExconLoggingInstrumentor do
  describe '.instrument' do
    let(:name) { 'foo' }
    let(:params) { { foo: 'bar' } }
    let(:logger) { instance_double('Logger') }

    subject { Bosh::OpenStackCloud::ExconLoggingInstrumentor }

    before do
      allow(Bosh::Clouds::Config).to receive(:logger).and_return(logger)
      allow(logger).to receive(:debug)
    end

    it 'logs requests' do
      subject.instrument(name, params)

      expect(logger).to have_received(:debug).with("#{name} #{params}")
    end

    it 'yields' do
      expect { |b| Bosh::OpenStackCloud::ExconLoggingInstrumentor.instrument(name, params, &b) }.to yield_control
    end

    it 'does not manipulate the original hash' do
      params_with_body = { body: '{}' }
      old_body = params_with_body.fetch(:body)

      subject.instrument(name, params_with_body)

      expect(params_with_body.fetch(:body)).to be(old_body)
    end

    context 'excon log messages are pretty' do
      before(:each) do
        subject.instrument(name, params)
      end

      context 'response' do
        let(:name) { 'excon.response' }
        let(:params) {
          {
            port: '1234',
            host: 'hostname.fqdn',
            path: '/api',
            headers: { 'fake' => 'fake-fake' },
            status_line: '200 1/1',
            body: { text: 'fake-text' }.to_json,
            cookies: [],
            status: '200',
            reason_phrase: 'OK',
            other_important_key: '10.1',
          }
        }

        it 'returns a formatted response message' do
          expect(logger).to have_received(:debug).with('excon.response 200 1/1 /api params: {"port":"1234","host":"hostname.fqdn","other_important_key":"10.1"} headers: {"fake":"fake-fake"} body: {"text":"fake-text"}')
        end
      end

      context 'request' do
        let(:name) { 'excon.request' }
        let(:params) {
          {
            ciphers: 'fake-ciphers',
            connection: 'connection-class',
            stack: 'stack-class',
            hostname: 'fake-host.fqdn',
            method: 'PUT',
            scheme: 'https',
            port: '8774',
            path: '/v1',
            headers: { 'fake-headers' => 'fake-value' },
            body: '{"fake-body":"fake-value"}',
            other_important_key: '10.1',
          }
        }

        it 'returns a formatted message' do
          expect(logger).to have_received(:debug).with('excon.request PUT https://fake-host.fqdn:8774/v1 params: {"other_important_key":"10.1"} headers: {"fake-headers":"fake-value"} body: {"fake-body":"fake-value"}')
        end
      end

      context 'error' do
        let(:name) { 'excon.error' }
        let(:error_double) {
          double('excon_error', response: double('response', data: {
            body: '{"itemNotFound": {"message": "Volume 123 could not be found.", "code": 404}}',
            cookies: [],
            headers: { 'fake-headers' => 'fake-value' },
            host: 'fake-host.fqdn',
            local_address: '1.2.2',
            local_port: 123,
            path: '/v2',
            port: 8776,
            reason_phrase: 'Not Found',
            remote_ip: '1.1.2',
            status: 404,
            status_line: "HTTP/1.1 404 Not Found\r\n",
          }))
        }
        let(:params) { { error: error_double } }

        it 'returns a formatted response message' do
          expect(logger).to have_received(:debug).with('excon.error HTTP/1.1 404 Not Found /v2 params: {"host":"fake-host.fqdn","local_address":"1.2.2","local_port":123,"port":8776,"remote_ip":"1.1.2"} headers: {"fake-headers":"fake-value"} body: {"itemNotFound": {"message": "Volume 123 could not be found.", "code": 404}}')
        end
      end
    end

    context 'with sensitive data' do
      context 'with non-json text in body' do
        let(:params) {
          {
            body: 'non-json',
            headers: {
              'Content-Type' => 'text/plain',
            },
          } }

        it 'returns original body' do
          redacted_params = subject.redact(params)

          expect(redacted_params[:body]).to eq(params[:body])
        end
      end

      context 'when content is not valid JSON' do
        let(:params) {
          {
            body: 'non-json',
            headers: {
              'Content-Type' => 'application/json',
            },
          } }

        it 'returns the original body' do
          redacted_params = subject.redact(params)

          expect(redacted_params[:body]).to eq(params[:body])
        end
      end

      context 'with v2 password in body' do
        let(:body) {
          {
            auth: {
              passwordCredentials: {
                password: 'my-password',
              },
            },
          } }
        let(:params) {
          {
            body: JSON.dump(body),
            headers: {
              'Content-Type' => 'application/json',
            },
          } }

        it 'redacts v2 password' do
          redacted_params = subject.redact(params)

          parsed_body = JSON.parse(redacted_params[:body])
          expect(parsed_body['auth']['passwordCredentials']['password']).to eq('<redacted>')
        end
      end

      context 'with v3 password in body' do
        let(:body) {
          {
            auth: {
              identity: {
                password: {
                  user: {
                    password: 'my-password',
                  },
                },
              },
            },
          } }
        let(:params) {
          {
            body: JSON.dump(body),
            headers: {
              'Content-Type' => 'application/json',
            },
          } }

        it 'redacts v3 password' do
          redacted_params = subject.redact(params)

          parsed_body = JSON.parse(redacted_params[:body])
          expect(parsed_body['auth']['identity']['password']['user']['password']).to eq('<redacted>')
        end
      end

      context 'with server.user_data in body' do
        let(:body) {
          {
            server: {
              user_data: 'user data',
            },
          } }
        let(:params) {
          {
            body: JSON.dump(body),
            headers: {
              'Content-Type' => 'application/json',
            },
          } }

        it 'redacts server.user_data' do
          redacted_params = subject.redact(params)

          parsed_body = JSON.parse(redacted_params[:body])
          expect(parsed_body['server']['user_data']).to eq('<redacted>')
        end
      end

      context 'with x-auth-token in header' do
        let(:headers) {
          {
            'X-Auth-Token' => 'token',
          } }
        let(:params) { { headers: headers } }

        it 'redacts params' do
          redacted_params = subject.redact(params)

          expect(redacted_params[:headers]['X-Auth-Token']).to eq('<redacted>')
        end
      end
    end

    context 'with non-string body (could be File)' do
      it 'does nothing' do
        params_with_file_body = { body: 5 }

        subject.instrument(name, params_with_file_body)

        expect(logger).to have_received(:debug).with("#{name} #{params_with_file_body}")
      end
    end
  end
end
