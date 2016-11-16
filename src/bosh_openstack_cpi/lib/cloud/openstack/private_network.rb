
module Bosh::OpenStackCloud
  class PrivateNetwork < Network

    attr_reader :nic

    def initialize(name, spec)
      super
      @nic = {}
      @nic['net_id'] = net_id if net_id
    end

    def net_id
      @spec.fetch("cloud_properties", {})
          .fetch("net_id"          , nil)
    end
  end
end
