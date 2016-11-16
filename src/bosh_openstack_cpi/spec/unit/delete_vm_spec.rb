# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Cloud do

  before(:each) do
     @registry = mock_registry
   end

  it "deletes an OpenStack server" do
    server = double("server", :id => "i-foobar", :name => "i-foobar")

    cloud = mock_cloud do |fog|
      allow(fog.compute.servers).to receive(:get).with("i-foobar").and_return(server)
    end

    allow(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:port_ids).and_return(['port_id'])
    allow(Bosh::OpenStackCloud::NetworkConfigurator).to receive(:cleanup_ports)
    allow(server).to receive(:destroy)
    allow(cloud).to receive(:wait_resource)
    allow(@registry).to receive(:delete_settings)

    cloud.delete_vm("i-foobar")

    expect(server).to have_received(:destroy)
    expect(cloud).to have_received(:wait_resource).with(server, [:terminated, :deleted], :state, true)
    expect(Bosh::OpenStackCloud::NetworkConfigurator).to have_received(:cleanup_ports).with(any_args, ['port_id'])
    expect(@registry).to have_received(:delete_settings).with("i-foobar")
  end
end
