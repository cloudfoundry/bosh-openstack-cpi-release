# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::NetworkConfigurator do

  def set_security_groups(spec, security_groups)
    spec["cloud_properties"] ||= {}
    spec["cloud_properties"]["security_groups"] = security_groups
  end

  def set_nics(spec, net_id)
    spec["cloud_properties"] ||= {}
  end

  let(:several_manual_networks) do
    spec = {}
    spec["network_a"] = manual_network_spec
    spec["network_a"]["ip"] = "10.0.0.1"
    spec["network_b"] = manual_network_spec
    spec["network_b"]["cloud_properties"]["net_id"] = "bar"
    spec["network_b"]["ip"] = "10.0.0.2"
    spec
  end

  it "should raise an error if the spec isn't a hash" do
    expect {
      Bosh::OpenStackCloud::NetworkConfigurator.new("foo")
    }.to raise_error ArgumentError, /Invalid spec, Hash expected,/
  end

  it "should raise a CloudError if no net_id is extracted for manual networks" do
    spec = {}
    spec["network_b"] = manual_network_without_netid_spec

    expect {
      Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
    }.to raise_error Bosh::Clouds::CloudError, "Manual network must have net_id"
  end

  it "should raise a CloudError if several manual networks have the same net_id" do
    spec = several_manual_networks
    spec["network_b"]["cloud_properties"]["net_id"] = "net"

    expect {
      Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
    }.to raise_error Bosh::Clouds::CloudError, "Manual network with id net is already defined"
  end

  it "should raise a CloudError if several dynamic networks are defined" do
    spec = {}
    spec["network_a"] = dynamic_network_spec
    spec["network_b"] = dynamic_network_spec

    expect {
      Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
    }.to raise_error Bosh::Clouds::CloudError, "Only one dynamic network per instance should be defined"
  end

  it "should raise a CloudError if several VIP networks are defined" do
    spec = {}
    spec["network_a"] = vip_network_spec
    spec["network_b"] = vip_network_spec

    expect {
      Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
    }.to raise_error Bosh::Clouds::CloudError, "Only one VIP network per instance should be defined"
  end

  it "should raise a CloudError if no dynamic or manual networks are defined" do
    spec = {}
    spec["network_a"] = vip_network_spec

    expect {
      Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
    }.to raise_error Bosh::Clouds::CloudError, "At least one dynamic or manual network should be defined"
  end

  describe "security groups" do
    it "should be extracted from both dynamic and vip network" do
      spec = {}
      spec["network_a"] = dynamic_network_spec
      set_security_groups(spec["network_a"], %w[foo])
      spec["network_b"] = vip_network_spec
      set_security_groups(spec["network_b"], %w[bar])

      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
      expect(nc.security_groups(nil)).to eq(%w[bar foo])
    end

    it "should be extracted from both manual and vip network" do
      spec = {}
      spec["network_a"] = manual_network_spec
      set_security_groups(spec["network_a"], %w[foo])
      spec["network_b"] = vip_network_spec
      set_security_groups(spec["network_b"], %w[bar])

      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
      expect(nc.security_groups(nil)).to eq(%w[bar foo])
    end

    it "should return the default groups if none are extracted" do
      spec = {}
      spec["network_a"] = {"type" => "dynamic"}

      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
      expect(nc.security_groups(%w[foo])).to eq(%w[foo])
    end

    it "should return an empty list if no default group is set" do
      spec = {}
      spec["network_a"] = {"type" => "dynamic"}

      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
      expect(nc.security_groups(nil)).to eq([])
    end

    it "should raise an error when it isn't an array" do
      spec = {}
      spec["network_a"] = dynamic_network_spec
      set_security_groups(spec["network_a"], "foo")

      expect {
        Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
      }.to raise_error ArgumentError, "security groups must be an Array"
    end
  end

  describe "private_ips" do
    it "should extract private ip address for manual network" do
      spec = {}
      spec["network_a"] = manual_network_spec
      spec["network_a"]["ip"] = "10.0.0.1"

      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
      expect(nc.private_ips).to eq(%w[10.0.0.1])
    end

    it "should extract private ip address from manual network when there's also vip network" do
      spec = {}
      spec["network_a"] = vip_network_spec
      spec["network_a"]["ip"] = "10.0.0.1"
      spec["network_b"] = manual_network_spec
      spec["network_b"]["ip"] = "10.0.0.2"

      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
      expect(nc.private_ips).to eq(%w[10.0.0.2])
    end

    it "should extract private ip addresses from multiple manual networks" do
      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(several_manual_networks)
      expect(nc.private_ips).to eq(%w[10.0.0.1 10.0.0.2])
    end

    it "should not extract private ip address for dynamic network" do
      spec = {}
      spec["network_a"] = dynamic_network_spec
      spec["network_a"]["ip"] = "10.0.0.1"

      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
      expect(nc.private_ips).to be_empty
    end
  end

  describe "nics" do
    it "should extract net_id from dynamic network" do
      spec = {}
      spec["network_a"] = dynamic_network_spec
      spec["network_a"]["cloud_properties"]["net_id"] = "foo"

      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
      expect(nc.nics).to eq([{"net_id" => "foo"}])
    end

    it "should extract net_id and IP address from all manual networks" do
      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(several_manual_networks)
      expect(nc.nics).to eq([
            {"net_id" => "net", "v4_fixed_ip" => "10.0.0.1"},
            {"net_id" => "bar", "v4_fixed_ip" => "10.0.0.2"},
          ])
    end

    it "should not extract ip address for dynamic network" do
      spec = {}
      spec["network_a"] = dynamic_network_spec
      spec["network_a"]["ip"] = "10.0.0.1"
      spec["network_a"]["cloud_properties"]["net_id"] = "foo"

      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
      expect(nc.nics).to eq([{"net_id" => "foo"}])
    end
  end

  describe "configure" do
    let(:vip_network) do
      network = double('vip_network')
      allow(Bosh::OpenStackCloud::VipNetwork).to receive(:new).and_return(network)
      network
    end
    let(:dynamic_network) do
      network = double('dynamic_network')
      allow(Bosh::OpenStackCloud::DynamicNetwork).to receive(:new).and_return(network)
      network
    end
    let(:manual_network) do
      network = double('manual_network')
      allow(Bosh::OpenStackCloud::ManualNetwork).to receive(:new).and_return(network)
      network
    end

    context "With vip network" do
      let(:network_spec) do
        {
          'network_a' => dynamic_network_spec,
          'network_b' => manual_network_spec,
          'network_c' => vip_network_spec
        }
      end

      it "configures the vip network if it exists" do
        expect(vip_network).to receive(:configure)
        network_configurator = Bosh::OpenStackCloud::NetworkConfigurator.new(network_spec)
        network_configurator.configure(nil, nil)
      end

      it "configures the other networks too" do
        allow(vip_network).to receive(:configure)
        expect(manual_network).to receive(:configure)
        expect(dynamic_network).to receive(:configure)
        network_configurator = Bosh::OpenStackCloud::NetworkConfigurator.new(network_spec)
        network_configurator.configure(nil, nil)
      end
    end

    context "No vip network" do
      let(:network_spec) do
        {
          'network_a' => dynamic_network_spec,
          'network_b' => manual_network_spec,
        }
      end

      it "disassociate allocated floating IP" do
        server = double("server", :id => "i-test")
        address = double("address", :id => "a-test", :ip => "10.0.0.1",
          :instance_id => "i-test")

        expect(manual_network).to receive(:configure)
        expect(dynamic_network).to receive(:configure)
        expect(vip_network).to_not receive(:configure)
        cloud = mock_cloud do |openstack|
          expect(openstack).to receive(:addresses).and_return([address])
        end
        expect(address).to receive(:server=).with(nil)

        network_configurator = Bosh::OpenStackCloud::NetworkConfigurator.new(network_spec)
        network_configurator.configure(cloud.openstack, server)
      end

      it "floating IPs allocated to other servers" do
        other_server = double("server", :id => "i-test2")
        address = double("address", :id => "a-test", :ip => "10.0.0.1",
          :instance_id => "i-test")

        expect(manual_network).to receive(:configure)
        expect(dynamic_network).to receive(:configure)
        expect(vip_network).to_not receive(:configure)

        cloud = mock_cloud do |openstack|
          expect(openstack).to receive(:addresses).and_return([address])
        end
        expect(address).to_not receive(:server=).with(nil)

        network_configurator = Bosh::OpenStackCloud::NetworkConfigurator.new(network_spec)
        network_configurator.configure(cloud.openstack, other_server)
      end

      it "no floating IPs allocated" do
        expect(manual_network).to receive(:configure)
        expect(dynamic_network).to receive(:configure)
        expect(vip_network).to_not receive(:configure)
        cloud = mock_cloud do |openstack|
          expect(openstack).to receive(:addresses).and_return([])
        end

        network_configurator = Bosh::OpenStackCloud::NetworkConfigurator.new(network_spec)
        network_configurator.configure(cloud.openstack, nil)
      end
    end
  end
end
