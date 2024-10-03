module Bosh::OpenStackCloud
  ##
  # Represents OpenStack dynamic network: where IaaS sets VM's IP
  class DynamicNetwork < PrivateNetwork
    def prepare(_openstack, _security_group_ids)
      cloud_error("Network with id '#{net_id}' is a dynamic network. VRRP is not supported for dynamic networks") if @allowed_address_pairs
    end
  end
end
