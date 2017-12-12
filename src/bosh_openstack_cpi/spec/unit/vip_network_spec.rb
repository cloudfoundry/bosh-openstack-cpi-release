require 'spec_helper'

describe Bosh::OpenStackCloud::VipNetwork do
  subject do
    described_class.new('network_b', network_spec)
  end
  let(:network_spec) { vip_network_spec.merge(cloud_properties) }
  let(:cloud_properties) { {} }

  describe 'configure' do
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

      it 'calls FloatingIp.reassociate' do
        server = double('server')
        allow(Bosh::OpenStackCloud::FloatingIp).to receive(:reassociate)

        subject.configure(openstack, server, 'network_id')

        expect(Bosh::OpenStackCloud::FloatingIp).to have_received(:reassociate).with(openstack, '10.0.0.1', server, 'network_id')
      end
    end

    context 'if it is a shared network' do
      let(:openstack) { double('openstack') }
      let(:cloud_properties) {
        {
          'cloud_properties' => { 'shared' => 'true' }
        }
      }

      before(:each) do
        allow(openstack).to receive(:with_openstack) { |&block| block.call }
      end

      it 'does not call FloatingIp.reassociate' do
        server = double('server')
        allow(Bosh::OpenStackCloud::FloatingIp).to receive(:reassociate)

        subject.configure(openstack, server, 'network_id')

        expect(Bosh::OpenStackCloud::FloatingIp).to_not have_received(:reassociate).with(openstack, '10.0.0.1', server, 'network_id')
      end
    end
  end

  describe '#shared?' do
    context 'with a shared network' do
      let(:cloud_properties) {
        {
          'cloud_properties' => { 'shared' => true }
        }
      }

      it 'returns true' do
        expect(subject.shared?).to eq(true)
      end
    end

    context 'without a shared network' do
      let(:cloud_properties) {
        {
          'cloud_properties' => { 'shared' => false }
        }
      }

      it 'returns false' do
        expect(subject.shared?).to eq(false)
      end
    end

    context 'if not specified' do
      let(:cloud_properties) { {} }

      it 'returns false' do
        expect(subject.shared?).to eq(false)
      end
    end
  end
end
