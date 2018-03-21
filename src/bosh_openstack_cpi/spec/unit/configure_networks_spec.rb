require 'spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  it 'forces recreation always' do
    expect {
      mock_cloud.configure_networks('i-test', 'net_a' => { 'type' => 'foo' })
    }.to raise_error(Bosh::Clouds::NotSupported, /network configuration change requires VM recreation/)
  end
end
