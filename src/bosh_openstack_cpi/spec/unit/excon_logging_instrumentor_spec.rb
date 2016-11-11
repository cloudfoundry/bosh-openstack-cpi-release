require 'spec_helper'

describe Bosh::OpenStackCloud::ExconLoggingInstrumentor do
  describe '.instrument' do
    let(:name) { 'foo' }
    let(:params) { { foo: 'bar'} }
    let(:logger) { instance_double('Logger') }

    subject {
      Bosh::OpenStackCloud::ExconLoggingInstrumentor
    }

    before do
      allow(Bosh::Clouds::Config).to receive(:logger).and_return(logger)
      allow(logger).to receive(:debug)
    end

    it 'logs requests' do
      subject.instrument(name, params)

      expect(logger).to have_received(:debug).with("#{name} #{params}")
    end

    it 'does not manipulate the original hash' do
      params_with_body = { body: '{}'}
      old_body = params_with_body.fetch(:body)

      subject.instrument(name, params_with_body)

      expect(params_with_body.fetch(:body)).to be(old_body)
    end

    context 'with v2 password in body' do
      let(:body) { {
          auth: {
              passwordCredentials: {
                  password: 'my-password'
              }
          }
      } }
      let(:params) { { body: JSON.dump(body) } }
      let(:expected_params) do
        expected_body = body.dup
        expected_body[:auth][:passwordCredentials][:password] = '<redacted>'

        {body: JSON.dump(expected_body)}
      end

      it 'redacts params' do
        subject.instrument(name, params)

        expect(logger).to have_received(:debug).with("#{name} #{expected_params}")
      end

    end

    context 'with non-string body (could be File)' do
      it 'does nothing' do
        params_with_file_body = {body: 5}

        subject.instrument(name, params_with_file_body)

        expect(logger).to have_received(:debug).with("#{name} #{params_with_file_body}")
      end
    end

    context 'with v3 password in body' do
      let(:body) { {
          auth: {
              identity: {
                  password: {
                      user: {
                        password: 'my-password'
                      }
                  }
              }
          }
      } }
      let(:params) { { body: JSON.dump(body) } }
      let(:expected_params) do
        expected_body = body.dup
        expected_body[:auth][:identity][:password][:user][:password] = '<redacted>'

        {body: JSON.dump(expected_body)}
      end


      it 'redacts params' do
        subject.instrument(name, params)

        expect(logger).to have_received(:debug).with("#{name} #{expected_params}")
      end

    end

    context 'with x-auth-token in header' do
      let(:headers) { {
          'X-Auth-Token' => 'token'
      } }
      let(:params) { { headers: headers } }
      let(:expected_params) do
        expected_headers = headers.dup
        expected_headers['X-Auth-Token'] = '<redacted>'

        {headers: expected_headers}
      end

      it 'redacts params' do
        subject.instrument(name, params)

        expect(logger).to have_received(:debug).with("#{name} #{expected_params}")
      end

    end

    it 'yields' do
      expect { |b| Bosh::OpenStackCloud::ExconLoggingInstrumentor.instrument(name, params, &b) }.to yield_control
    end

  end
end
