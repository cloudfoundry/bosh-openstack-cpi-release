require "spec_helper"

describe Bosh::OpenStackCloud::VipNetwork do
  describe "configure" do
    let(:cloud) do
      mock_cloud do |openstack|
        expect(openstack).to receive(:addresses).and_return([address])
      end
    end

    let(:server) { double("server", :id => "i-test") }
    let(:vip_network) { described_class.new("network_b", vip_network_spec) }

    context "no floating IP provided for vip network" do
      let(:vip_network) do
        spec = vip_network_spec
        spec['ip'] = nil
        described_class.new("network_b", spec)
      end

      it "fails" do
        expect {
          vip_network.configure(nil, nil)
        }.to raise_error Bosh::Clouds::CloudError, /No IP provided for vip network/
      end
    end

    context "ip already associated with an instance" do
      let(:address) do
        double("address", :id => "network_b", :ip => "10.0.0.1", :instance_id => "i-test")
      end

      it "adds floating ip to the server for vip network" do
        expect(address).to receive(:server=).with(nil)
        expect(address).to receive(:server=).with(server)

        vip_network.configure(cloud.compute, server)
      end
    end

    context "ip not already associated with an instance" do
      let(:address) do
        double("address", :id => "network_b", :ip => "10.0.0.1", :instance_id => nil)
      end

      it "adds free floating ip to the server for vip network" do
        expect(address).to_not receive(:server=).with(nil)
        expect(address).to receive(:server=).with(server)

        vip_network.configure(cloud.compute, server)
      end
    end

    context "no floating IP allocated for vip network" do
      let(:address) do
        double("address", :id => "network_b", :ip => "10.0.0.2")
      end

      it "fails" do
        expect(address).to_not receive(:server=)

        expect {
          vip_network.configure(cloud.compute, nil)
        }.to raise_error Bosh::Clouds::CloudError, /Floating IP .* not allocated/
      end
    end
  end
end
