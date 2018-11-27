require 'spec_helper'

shared_examples 'a registry' do
  it { is_expected.to respond_to(:update_settings).with(2).arguments }
  it { is_expected.to respond_to(:read_settings).with(1).arguments }
  it { is_expected.to respond_to(:delete_settings).with(1).arguments }
  it { is_expected.to respond_to(:endpoint) }
end

describe Bosh::OpenStackCloud::NoopRegistry do
  it_behaves_like 'a registry'
  describe '#read_settings' do
    it 'returns a hash' do
      expect(subject.read_settings('registry-key')).to be_instance_of(Hash)
    end
  end
end

describe Bosh::Cpi::RegistryClient do
  subject { Bosh::Cpi::RegistryClient.new('fake_endpoint', 'fake_user', 'fake_password') }
  it_behaves_like 'a registry'
end
