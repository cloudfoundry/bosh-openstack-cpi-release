require "spec_helper"

describe Bosh::OpenStackCloud::VipNetwork do
  describe "configure" do

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

  end
end
