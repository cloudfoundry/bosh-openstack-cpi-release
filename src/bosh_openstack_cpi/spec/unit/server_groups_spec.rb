require 'spec_helper'

describe Bosh::OpenStackCloud::ServerGroups do
  let(:fog_server_groups) {
    double(:server_groups, list: [],
      create: OpenStruct.new('id' => '999', 'name' => 'fake-uuid-fake-group', 'policy' => 'soft-anti-affinity'))
  }
  subject(:server_groups) {
    openstack = double(:openstack, compute: double(:compute, server_groups: fog_server_groups))
    Bosh::OpenStackCloud::ServerGroups.new(openstack)
  }

  it 'uses name derived from uuid and bosh groups' do
    server_groups.find_or_create('fake-uuid', 'fake-group')

    expect(fog_server_groups).to have_received(:create).with('fake-uuid-fake-group')
  end

  context 'when a server_group with soft-anti-affinity policy already exists for this name' do
    let(:fog_server_groups) {
      double(:server_groups, list:
        [
          OpenStruct.new('id' => '123', 'name' => 'fake-uuid-fake-group', 'policy' => 'soft-anti-affinity'),
          OpenStruct.new('id' => '234', 'name' => 'other-uuid-other-group', 'policy' => 'soft-anti-affinity'),
          OpenStruct.new('id' => '456', 'name' => 'fake-uuid-fake-group', 'policy' => 'anti-affinity')
        ],
        create: OpenStruct.new('id' => '999', 'name' => 'fake-uuid-fake-group', 'policy' => 'soft-anti-affinity')
      )
    }

    it 'returns id of existing server group' do
      id = server_groups.find_or_create('fake-uuid','fake-group')

      expect(fog_server_groups).to have_received(:list)
      expect(fog_server_groups).to_not have_received(:create)
      expect(id).to eq('123')
    end
  end

  context 'when no server group exists for that name' do
    it 'creates the server group and returns id' do
      id = server_groups.find_or_create('fake-uuid', 'fake-group')

      expect(fog_server_groups).to have_received(:list)
      expect(fog_server_groups).to have_received(:create)
      expect(id).to eq('999')
    end
  end
end
