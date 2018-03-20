require 'spec_helper'

describe Bosh::OpenStackCloud::VipNetwork do
  describe 'configure' do
    subject do
      described_class.new('network_b', network_spec)
    end

    let(:network_spec) { vip_network_spec }

    context 'no floating IP provided for vip network' do
      before(:each) do
        network_spec['ip'] = nil
      end

      it 'fails' do
        expect {
          subject.configure(nil, nil, nil)
        }.to raise_error Bosh::Clouds::CloudError, /No IP provided for vip network/
      end
    end

    context 'floating IP is provided' do
      let(:openstack) { double('openstack') }
      before { allow(openstack).to receive(:with_openstack) { |&block| block.call } }

      it 'calls FloatingIp.reassiciate' do
        server = double('server')
        allow(Bosh::OpenStackCloud::FloatingIp).to receive(:reassociate)

        subject.configure(openstack, server, 'network_id')

        expect(Bosh::OpenStackCloud::FloatingIp).to have_received(:reassociate).with(openstack, '10.0.0.1', server, 'network_id')
      end
    end
  end
end
