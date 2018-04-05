require 'spec_helper'

describe Bosh::OpenStackCloud::RequestMessage do
  describe '.format' do
    subject { Bosh::OpenStackCloud::RequestMessage.new(params) }

    let(:params) {
      {
        ciphers: 'fake-ciphers',
        connection: 'connection-class',
        stack: 'stack-class',
        hostname: 'fake-host.fqdn',
        __construction_args: 'fake-args',
        uri_parser: 'URI',
        instrumentor: 'CLASS',
        method: 'PUT',
        scheme: 'https',
        port: '8774',
        path: '/v1',
        headers: { 'fake-headers' => 'fake-value' },
        body: '{"fake-body":"fake-value"}',
        other_important_key: '1234',
      }
    }
    let(:output) { subject.format }

    it 'removes clutter from params' do
      expect(output).not_to include('"ciphers":')
      expect(output).not_to include('"connection":')
      expect(output).not_to include('"stack":')
      expect(output).not_to include('"instrumentor":')
      expect(output).not_to include('"uri_parser":')
      expect(output).not_to include('"__construction_args":')
    end

    it 'keeps everything else in the params' do
      expect(output).to include('params: {"other_important_key":"1234"}')
    end

    it 'includes url' do
      expect(output).to include('PUT https://fake-host.fqdn:8774/v1')
    end

    it 'includes the headers as json' do
      expect(output).to include('headers: {"fake-headers":"fake-value"}')
    end

    it 'includes the body as json' do
      expect(output).to include('body: {"fake-body":"fake-value"}')
    end

    it 'orders correctly' do
      expect(output).to match(%r(^PUT https://fake-host.fqdn:8774/v1 params: {.*} headers: {.*} body: {.*}$))
    end

    context 'when body is empty' do
      it 'outputs null for body' do
        params.delete(:body)
        expect(output).to match(%r(^PUT https://fake-host.fqdn:8774/v1 params: {.*} headers: {.*} body: null$))
      end
    end
  end
end
