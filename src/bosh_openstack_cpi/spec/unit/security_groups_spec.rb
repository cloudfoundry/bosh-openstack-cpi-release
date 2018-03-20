require 'spec_helper'

describe Bosh::OpenStackCloud::SecurityGroups do
  let(:security_groups) { [] }
  let(:compute) { double('compute', security_groups: security_groups) }
  let(:network) { double('network', security_groups: security_groups) }
  let(:use_nova_networking?) { false }
  let(:openstack) { double('openstack', compute: compute, network: network, use_nova_networking?: use_nova_networking?) }

  before { allow(openstack).to receive(:with_openstack) { |&block| block.call } }

  describe '.retrieve_and_validate_security_groups' do
    context 'security group picking' do
      let(:security_groups) {
        [
          double('default-security-group', name: 'default-security-group'),
          double('network-spec-security-group', name: 'network-spec-security-group'),
          double('resource-pool-spec-security-group', name: 'resource-pool-spec-security-group'),
        ]
      }

      context 'when security groups specified in resource pool spec' do
        it 'picks those' do
          picked_security_groups = Bosh::OpenStackCloud::SecurityGroups.select_and_retrieve(
            openstack,
            ['default-security-group'],
            [],
            ['resource-pool-spec-security-group'],
          )
          expect(picked_security_groups.size).to eq(1)
          expect(picked_security_groups.first.name).to eq('resource-pool-spec-security-group')
        end
      end

      context 'when security groups specified in network spec' do
        it 'picks those' do
          picked_security_groups = Bosh::OpenStackCloud::SecurityGroups.select_and_retrieve(
            openstack,
            ['default-security-group'],
            ['network-spec-security-group'],
            [],
          )
          expect(picked_security_groups.size).to eq(1)
          expect(picked_security_groups.first.name).to eq('network-spec-security-group')
        end
      end

      context 'when resource pool spec and network spec define security groups' do
        it 'picks the resource pool security groups' do
          picked_security_groups = Bosh::OpenStackCloud::SecurityGroups.select_and_retrieve(
            openstack,
            ['default security group'],
            ['network-spec-security-group'],
            ['resource-pool-spec-security-group'],
          )
          expect(picked_security_groups.size).to eq(1)
          expect(picked_security_groups.first.name).to eq('resource-pool-spec-security-group')
        end
      end

      context 'when security groups are neither specified in network spec nor resource pool spec' do
        it 'picks the default security group' do
          picked_security_groups = Bosh::OpenStackCloud::SecurityGroups.select_and_retrieve(
            openstack,
            ['default-security-group'],
            [],
            [],
          )
          expect(picked_security_groups.size).to eq(1)
          expect(picked_security_groups.first.name).to eq('default-security-group')
        end
      end
    end

    context 'when a picked security group does not exist in openstack' do
      let(:security_groups) { [] }

      it 'raises an error' do
        expect {
          Bosh::OpenStackCloud::SecurityGroups.select_and_retrieve(
            openstack,
            ['default-security-group'],
            [],
            [],
          )
        }.to raise_error Bosh::Clouds::CloudError, "Security group `default-security-group' not found"
      end
    end

    context 'when openstack is configured with `use_nova_networking`' do
      let(:use_nova_networking?) { true }

      let(:security_groups) {
        [
          double('default-security-group', name: 'default-security-group'),
        ]
      }

      it 'uses nova to retrieve the security groups' do
        Bosh::OpenStackCloud::SecurityGroups.select_and_retrieve(
          openstack,
          ['default-security-group'],
          [],
          [],
        )

        expect(compute).to have_received(:security_groups)
        expect(network).to_not have_received(:security_groups)
      end
    end

    context 'when openstack is configured without `use_nova_networking` (default)' do
      let(:use_nova_networking?) { false }

      let(:security_groups) {
        [
          double('default-security-group', name: 'default-security-group'),
        ]
      }

      it 'uses neutron to retrieve the security groups' do
        Bosh::OpenStackCloud::SecurityGroups.select_and_retrieve(
          openstack,
          ['default-security-group'],
          [],
          [],
        )

        expect(network).to have_received(:security_groups)
        expect(compute).to_not have_received(:security_groups)
      end
    end
  end
end
