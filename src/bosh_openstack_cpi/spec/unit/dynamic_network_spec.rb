require 'spec_helper'

describe Bosh::OpenStackCloud::DynamicNetwork do
  subject { Bosh::OpenStackCloud::DynamicNetwork.new('default', dynamic_network_with_netid_spec) }

  context 'allowed_address_pair is configured' do
    it 'raises an error' do
      allowed_address_pairs = '10.0.0.10'
      subject.allowed_address_pairs = allowed_address_pairs

      expect {
        subject.prepare(nil, [])
      }.to raise_error Bosh::Clouds::CloudError, "Network with id '#{subject.net_id}' is a dynamic network. VRRP is not supported for dynamic networks"
    end
  end

  context 'allowed_address_pair is not configured' do
    it 'does not raise an error' do
      expect {
        subject.prepare(nil, [])
      }.to_not raise_error
    end
  end
end
