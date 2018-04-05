require 'spec_helper'

describe Bosh::OpenStackCloud::ResponseMessage do
  describe '.format' do
    subject { Bosh::OpenStackCloud::ResponseMessage.new(params) }

    let(:params) {
      {
        port: 1234,
        host: 'hostname.fqdn',
        path: '/api',
        headers: { 'other_important_key' => '' },
        status_line: "HTTP/1.0 200 OK\r\n",
        body: {},
        cookies: [],
        status: '200',
        reason_phrase: 'OK',
        other_important_key: '10.1',
      }
    }
    let(:output) { subject.format }

    it 'removes clutter from params' do
      expect(output).not_to include('"cookies":')
      expect(output).not_to include('"status":')
      expect(output).not_to include('"reason_phrase":')
    end

    it 'includes host, port and everything else in the params' do
      expect(output).to include('params: {"port":1234,"host":"hostname.fqdn","other_important_key":"10.1"}')
    end

    it 'includes the response status line' do
      expect(output).to include('HTTP/1.0 200 OK')
    end

    it 'removes the response status line from headers' do
      expect(output).to include('headers: {"other_important_key":""}')
    end

    it 'includes the path' do
      expect(output).to include('/api')
    end

    it 'includes the params which include headers' do
      expect(output).to match(/headers: {.*}/)
    end

    it 'includes the params which include body' do
      expect(output).to match(/body: {.*}/)
    end

    it 'orders correctly' do
      expect(output).to match(%r(^HTTP/1.0 200 OK /api params: {.*} headers: {.*} body: {.*}$))
    end
  end
end
