# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require 'spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  let(:server) { double('server', :id => 'i-foobar', :metadata => double('metadata')) }

  it 'should only set metadata' do
    @cloud = mock_cloud do |openstack|
      expect(openstack.servers).to receive(:get).with('i-foobar').and_return(server)
    end
    expect(server.metadata).to receive(:get).with(:registry_key).and_return(nil)
    metadata = {:job => 'job', :index => 'index'}

    expect(Bosh::OpenStackCloud::TagManager).to receive(:tag).with(server, :job, 'job')
    expect(Bosh::OpenStackCloud::TagManager).to receive(:tag).with(server, :index, 'index')

    @cloud.set_vm_metadata('i-foobar', metadata)
  end

  context 'with registry_key set' do

    it "sets the vm name 'job/index'" do
      @cloud = mock_cloud do |openstack|
        expect(openstack.servers).to receive(:get).with('i-foobar').and_return(server)
        expect(openstack).to receive(:update_server).with('i-foobar', {'name' => 'job/index'})
      end
      expect(server.metadata).to receive(:get).with(:registry_key).and_return(double('metadatum'))
      metadata = {'job' => 'job', 'index' => 'index'}

      allow(Bosh::OpenStackCloud::TagManager).to receive(:tag)

      @cloud.set_vm_metadata("i-foobar", metadata)
    end

    it "sets the vm name 'compilation/x'" do
      @cloud = mock_cloud do |openstack|
        expect(openstack.servers).to receive(:get).with('i-foobar').and_return(server)
        expect(openstack).to receive(:update_server).with('i-foobar', {'name' => 'compilation/x'})
      end
      expect(server.metadata).to receive(:get).with(:registry_key).and_return(double('metadatum'))
      metadata = {'compiling' => 'x'}

      allow(Bosh::OpenStackCloud::TagManager).to receive(:tag)

      @cloud.set_vm_metadata("i-foobar", metadata)
    end

  end
end