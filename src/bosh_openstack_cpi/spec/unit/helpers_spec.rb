require 'spec_helper'

describe Bosh::OpenStackCloud::Helpers do
  subject(:cloud) { mock_cloud }

  describe 'with_openstack' do
    let(:openstack) { double('openstack') }

    context 'when openstack raises an unexpected exception' do
      before { allow(openstack).to receive(:servers).and_raise(NoMemoryError) }

      it 'raises the exception without waiting' do
        expect(cloud).not_to receive(:sleep)

        expect {
          cloud.with_openstack do
            openstack.servers
          end
        }.to raise_error(NoMemoryError)
      end
    end

    context 'when openstack raises ServiceUnavailable' do
      let(:headers) { {} }
      let(:body) do
        {
          'overLimit' => {
            'message' => 'No server is available to handle this request.',
            'code' => 503,
          }
        }
      end
      let(:response) { Excon::Response.new(body: JSON.dump(body), headers: headers) }

      before do
        allow(openstack).to receive(:servers) do
          # next time don't raise the same exception to avoid looping
          allow(openstack).to receive(:servers).and_return(nil)

          raise Excon::Errors::ServiceUnavailable.new('', '', response)
        end
      end

      it 'retries until the max number of retries is reached' do
        allow(openstack).to receive(:servers).exactly(11).times.
          and_raise(Excon::Errors::ServiceUnavailable.new('', '', response))
        expect(cloud).to receive(:sleep).with(3).exactly(10).times

        expect {
          cloud.with_openstack do
            openstack.servers
          end
        }.to raise_error(Bosh::Clouds::CloudError,
                         'OpenStack API Service Unavailable error. Check task debug log for details.')

      end
    end

    context 'when openstack raises RequestEntityTooLarge' do
      let(:headers) { {} }
      let(:body) do
        {
          'overLimit' => {
            'message' => 'This request was rate-limited.',
            'code' => 413,
            'details' => 'Only 10 POST request(s) can be made to * every minute.'
          }
        }
      end
      let(:response) { Excon::Response.new(body: JSON.dump(body), headers: headers) }

      before do
        allow(openstack).to receive(:servers) do
          # next time don't raise the same exception to avoid looping
          allow(openstack).to receive(:servers).and_return(nil)

          raise Excon::Errors::RequestEntityTooLarge.new('', '', response)
        end
      end

      it 'retries after waiting a default number of seconds' do
        expect(cloud).to receive(:sleep).with(3)

        cloud.with_openstack do
          openstack.servers
        end
      end

      it 'retries until the max number of retries is reached' do
        allow(openstack).to receive(:servers).exactly(11).times.
          and_raise(Excon::Errors::RequestEntityTooLarge.new('', '', response))
        expect(cloud).to receive(:sleep).with(3).exactly(10).times

        expect {
          cloud.with_openstack do
            openstack.servers
          end
        }.to raise_error(Bosh::Clouds::CloudError,
                         /OpenStack API Request Entity Too Large error:/)
      end

      context 'when the response includes a retryAfter in the body' do
        before { body['overLimit']['retryAfter'] = 5 }

        it 'retries after waiting the amount of seconds received at the response body' do
          expect(cloud).to receive(:sleep).with(5)

          cloud.with_openstack do
            openstack.servers
          end
        end
      end

      context 'when the response includes a Retry-After header' do
        before { headers['Retry-After'] = 5 }

        it 'retries after waiting the amount of seconds received in the Retry-After header' do
          expect(cloud).to receive(:sleep).with(5)

          cloud.with_openstack do
            openstack.servers
          end
        end
      end

      context 'when OpenStack error message contains overLimit,' do

        let(:body) do
          {
              'overLimit' => {
                  'message' => 'Specific OpenStack error message',
                  'code' => 413,
                  'details' => 'Only 10 POST request(s) can be made to * every minute.',
                  'retryAfter' => 0
              }
          }
        end

        it 'enriches the BOSH error message' do
          allow(openstack).to receive(:servers).and_raise(Excon::Errors::RequestEntityTooLarge.new('', '', response))

          expected_message = "OpenStack API Request Entity Too Large error: Specific OpenStack error message\nCheck task debug log for details."

          expect {
            cloud.with_openstack do
              openstack.servers
            end
          }.to raise_error(Bosh::Clouds::CloudError, expected_message)
        end
      end

      context 'when OpenStack error message does not contain overLimit,' do

        let(:body) do
          {
              "notOverLimit" => "arbitrary content"
          }
        end

        it 'enriches the BOSH error message with the whole response body' do
          expected_response_body = JSON.dump({"notOverLimit" => "arbitrary content"})
          expected_message = "OpenStack API Request Entity Too Large error: #{expected_response_body}\nCheck task debug log for details."

          expect {
            cloud.with_openstack do
              openstack.servers
            end
          }.to raise_error(Bosh::Clouds::CloudError, expected_message)
        end
      end
    end

    context 'when openstack raises BadRequest' do

      before do
        response = Excon::Response.new(body: body)
        expect(openstack).to receive(:servers).and_raise(Excon::Errors::BadRequest.new('', '', response))
      end

      let(:body) { JSON.dump({}) }

      context 'when the error includes a `message` property on 2nd level of body' do
        let(:body) { JSON.dump('SomeError' => {'message' => 'some-message'}) }

        it 'should raise a CloudError exception with OpenStack API message' do
          expect {
            cloud.with_openstack do
              openstack.servers
            end
          }.to raise_error(Bosh::Clouds::CloudError,
                           'OpenStack API Bad Request (some-message). Check task debug log for details.')
        end
      end

      context 'when the error does not include a message' do
        let(:body) { JSON.dump('SomeError' => {'some_key' => 'some_val'}) }

        it 'should raise a CloudError exception with OpenStack API message without anything from body' do
          expect {
            cloud.with_openstack do
              openstack.servers
            end
          }.to raise_error(Bosh::Clouds::CloudError,
                           'OpenStack API Bad Request. Check task debug log for details.')
        end
      end

      context 'when the response has an empty body' do
        let(:body) { '' }

        it 'should raise a CloudError exception without OpenStack API message' do
          expect {
            cloud.with_openstack do
              openstack.servers
            end
          }.to raise_error(Bosh::Clouds::CloudError,
                           'OpenStack API Bad Request. Check task debug log for details.')
        end
      end
    end

    context 'when openstack raises Conflict' do
      before do
        response = Excon::Response.new(body: body)
        expect(openstack).to receive(:servers).and_raise(Excon::Errors::Conflict.new('', '', response))
      end

      let(:body) { JSON.dump({}) }

      context 'when the error includes a `message` property on 2nd level of body' do
        let(:body) { JSON.dump('SomeError' => {'message' => 'some-message'}) }

        it 'should raise a CloudError exception with OpenStack API message' do
          expect {
            cloud.with_openstack do
              openstack.servers
            end
          }.to raise_error(Bosh::Clouds::CloudError,
                           'OpenStack API Conflict (some-message). Check task debug log for details.')
        end
      end

      context 'when the error does not include a message' do
        let(:body) { JSON.dump('SomeError' => {'some_key' => 'some_val'}) }

        it 'should raise a CloudError exception with OpenStack API message without anything from body' do
          expect {
            cloud.with_openstack do
              openstack.servers
            end
          }.to raise_error(Bosh::Clouds::CloudError,
                           'OpenStack API Conflict. Check task debug log for details.')
        end
      end

      context 'when the response has an empty body' do
        let(:body) { '' }

        it 'should raise a CloudError exception without OpenStack API message' do
          expect {
            cloud.with_openstack do
              openstack.servers
            end
          }.to raise_error(Bosh::Clouds::CloudError,
                           'OpenStack API Conflict. Check task debug log for details.')
        end
      end
    end

    context 'when openstack raises InternalServerError' do
      it 'should retry the max number of retries before raising a CloudError exception' do
        expect(openstack).to receive(:servers).exactly(11)
          .and_raise(Excon::Errors::InternalServerError.new('InternalServerError'))
        expect(cloud).to receive(:sleep).with(3).exactly(10)

        expect {
          cloud.with_openstack do
            openstack.servers
          end
        }.to raise_error(Bosh::Clouds::CloudError,
                         'OpenStack API Internal Server error. Check task debug log for details.')
      end
    end

    context 'when openstack raises Fog::Errors::NotFound' do
      it 'should raise a CloudError with the original OpenStack message' do
        openstack_error_message = 'Could not find service network. Have compute, compute_legacy, identity, image, volume, volumev2'

        expect {
          cloud.with_openstack { raise Fog::Errors::NotFound, openstack_error_message }
        }.to raise_error(Bosh::Clouds::CloudError,
                         "OpenStack API service not found error: #{openstack_error_message}\nCheck task debug log for details.")
      end
    end
  end

  describe 'parse_openstack_response' do
    it 'should return nil if response has no body' do
      response = Excon::Response.new()

      expect(cloud.parse_openstack_response(response, 'key')).to be_nil
    end

    it 'should return nil if response has an empty string body' do
      response = Excon::Response.new(:body => JSON.dump(''))

      expect(cloud.parse_openstack_response(response, 'key')).to be_nil
    end

    it 'should return nil if response has a nil body' do
      response = Excon::Response.new(:body => JSON.dump(nil))

      expect(cloud.parse_openstack_response(response, 'key')).to be_nil
    end

    it 'should return nil if response is not JSON' do
      response = Excon::Response.new(:body => 'foo = bar')

      expect(cloud.parse_openstack_response(response, 'key')).to be_nil
    end

    it 'should return nil if response is no key is found' do
      response = Excon::Response.new(:body => JSON.dump({'foo' => 'bar'}))

      expect(cloud.parse_openstack_response(response, 'key')).to be_nil
    end

    it 'should return the contents if key is found' do
      response = Excon::Response.new(:body => JSON.dump({'key' => 'foo'}))

      expect(cloud.parse_openstack_response(response, 'key')).to eql('foo')
    end

    it 'should return the contents of the first key found' do
      response = Excon::Response.new(:body => JSON.dump({'key1' => 'foo', 'key2' => 'bar'}))

      expect(cloud.parse_openstack_response(response, 'key2', 'key1')).to eql('bar')
    end
  end
end
