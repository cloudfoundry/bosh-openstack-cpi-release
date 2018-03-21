require 'spec_helper'

describe Bosh::OpenStackCloud::ResourcePool do
  describe '.security_groups' do
    context 'when given resource_pool_spec is nil' do
      it 'returns an empty array' do
        expect(Bosh::OpenStackCloud::ResourcePool.security_groups(nil)).to eq([])
      end
    end

    context "when given resource_pool_spec contains no 'security_group'" do
      it 'returns an empty array' do
        expect(Bosh::OpenStackCloud::ResourcePool.security_groups(nil)).to eq([])
      end
    end

    context 'when security_group is not an array' do
      it 'raises an error' do
        expect {
          Bosh::OpenStackCloud::ResourcePool.security_groups('security_groups' => 'not an array')
        }.to raise_error ArgumentError, 'security groups must be an Array'
      end
    end

    context 'when security_groups is an array' do
      it 'returns the security_group array' do
        expect(Bosh::OpenStackCloud::ResourcePool.security_groups(
                 'security_groups' => ['some-security-group'],
        )).to eq(['some-security-group'])
      end
    end
  end
end
