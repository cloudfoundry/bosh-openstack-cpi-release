# Copyright (c) 2009-2013 VMware, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::ManualNetwork do
  it "should fail if spec is not a hash" do
    expect {
      Bosh::OpenStackCloud::ManualNetwork.new("default", [])
    }.to raise_error ArgumentError, /Invalid spec, Hash expected/
  end

  it "should set the IP in manual networking" do
    network_spec = manual_network_spec
    network_spec["ip"] = "172.20.214.10"
    mn = Bosh::OpenStackCloud::ManualNetwork.new("default", network_spec)

    expect(mn.private_ip).to eq("172.20.214.10")
  end
end
