variable "dns_nameservers" {
   default = ""
   description = "Comma-separated list of DNS server IPs"
}

variable "region_name" {
  description = "OpenStack region name"
}

variable "e2e_router_id" {
}

# no-dhcp network
resource "openstack_networking_network_v2" "v3_e2e_no_dhcp_1_net" {
  region         = "${var.region_name}"
  name           = "v3-e2e-no-dhcp-1"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "v3_e2e_no_dhcp_1_subnet" {
  region           = "${var.region_name}"
  network_id       = "${openstack_networking_network_v2.v3_e2e_no_dhcp_1_net.id}"
  cidr             = "10.0.9.0/24"
  ip_version       = 4
  name             = "v3-e2e-no-dhcp-1-sub"
  allocation_pools = {
    start = "10.0.9.200"
    end   = "10.0.9.254"
  }
  gateway_ip       = "10.0.9.1"
  enable_dhcp      = "false"
  dns_nameservers = ["${compact(split(",",var.dns_nameservers))}"]
}

resource "openstack_networking_router_interface_v2" "v3_e2e_no_dhcp_1_port" {
  region    = "${var.region_name}"
  router_id = "${var.e2e_router_id}"
  subnet_id = "${openstack_networking_subnet_v2.v3_e2e_no_dhcp_1_subnet.id}"
}

resource "openstack_networking_network_v2" "v3_e2e_no_dhcp_2_net" {
  region         = "${var.region_name}"
  name           = "v3-e2e-no-dhcp-2"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "v3_e2e_no_dhcp_2_subnet" {
  region           = "${var.region_name}"
  network_id       = "${openstack_networking_network_v2.v3_e2e_no_dhcp_2_net.id}"
  cidr             = "10.0.10.0/24"
  ip_version       = 4
  name             = "v3-e2e-no-dhcp-2-sub"
  allocation_pools = {
    start = "10.0.10.200"
    end   = "10.0.10.254"
  }
  gateway_ip       = "10.0.10.1"
  enable_dhcp      = "false"
  dns_nameservers = ["${compact(split(",",var.dns_nameservers))}"]
}

resource "openstack_networking_router_interface_v2" "v3_e2e_no_dhcp_2_port" {
  region    = "${var.region_name}"
  router_id = "${var.e2e_router_id}"
  subnet_id = "${openstack_networking_subnet_v2.v3_e2e_no_dhcp_2_subnet.id}"
}
# end no-dhcp networks

output "v3_e2e_net_no_dhcp_1_id" {
  value = "${openstack_networking_network_v2.v3_e2e_no_dhcp_1_net.id}"
}

output "v3_e2e_net_no_dhcp_2_id" {
  value = "${openstack_networking_network_v2.v3_e2e_no_dhcp_2_net.id}"
}
