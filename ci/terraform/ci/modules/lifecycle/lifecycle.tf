variable "dns_nameservers" {
  description = "DNS server IPs"
  type = 'list'
}

variable "region_name" {}

variable "default_router_id" {}

variable "ext_net_name" {
  description = "OpenStack external network name to register floating IP"
}

variable "use_lbaas" {
  default = "false"
  description = "When set to 'true', all necessary LBaaS V2 resources are created."
}

variable "lbaas_pool_name" {
  default = "Lifecycle Pool"
}

output "lifecycle_openstack_net_id" {
  value = "${openstack_networking_network_v2.lifecycle_net.id}"
}

output "lifecycle_manual_ip" {
  value = "${cidrhost(openstack_networking_subnet_v2.lifecycle_subnet.cidr, 3)}"
}

output "lifecycle_allowed_address_pairs" {
  value = "${openstack_networking_port_v2.allowed_address_pairs.all_fixed_ips[0]}"
}

output "lifecycle_net_id_no_dhcp_1" {
  value = "${openstack_networking_network_v2.lifecycle_net_no_dhcp_1.id}"
}

output "lifecycle_no_dhcp_manual_ip_1" {
  value = "${cidrhost(openstack_networking_subnet_v2.lifecycle_subnet_no_dhcp_1.cidr, 3)}"
}

output "lifecycle_net_id_no_dhcp_2" {
  value = "${openstack_networking_network_v2.lifecycle_net_no_dhcp_2.id}"
}

output "lifecycle_no_dhcp_manual_ip_2" {
  value = "${cidrhost(openstack_networking_subnet_v2.lifecycle_subnet_no_dhcp_2.cidr, 3)}"
}

output "lifecycle_floating_ip" {
  value = "${openstack_networking_floatingip_v2.lifecycle_floating_ip.address}"
}

output "lifecycle_lb_pool_name" {
  value = "${var.use_lbaas == "true" ? var.lbaas_pool_name : ""}"
}

resource "openstack_networking_network_v2" "lifecycle_net" {
  region         = "${var.region_name}"
  name           = "lifecycle"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "lifecycle_subnet" {
  region           = "${var.region_name}"
  network_id       = "${openstack_networking_network_v2.lifecycle_net.id}"
  cidr             = "10.0.1.0/24"
  ip_version       = 4
  name             = "lifecycle_sub"
  allocation_pools = {
    start = "10.0.1.200"
    end   = "10.0.1.254"
  }
  gateway_ip       = "10.0.1.1"
  enable_dhcp      = "true"
  dns_nameservers = "${var.dns_nameservers}"
}

resource "openstack_networking_port_v2" "allowed_address_pairs" {
  name           = "allowed_address_pairs"
  network_id     = "${openstack_networking_network_v2.lifecycle_net.id}"
  fixed_ip = {
    subnet_id = "${openstack_networking_subnet_v2.lifecycle_subnet.id}"
  }
  admin_state_up = "true"
}

resource "openstack_networking_network_v2" "lifecycle_net_no_dhcp_1" {
  region         = "${var.region_name}"
  name           = "lifecycle-no-dhcp-1"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "lifecycle_subnet_no_dhcp_1" {
  region           = "${var.region_name}"
  network_id       = "${openstack_networking_network_v2.lifecycle_net_no_dhcp_1.id}"
  cidr             = "10.1.1.0/24"
  ip_version       = 4
  name             = "lifecycle-subnet-no-dhcp-1"
  gateway_ip       = "10.1.1.1"
  enable_dhcp      = "false"
  dns_nameservers = "${var.dns_nameservers}"
}

resource "openstack_networking_network_v2" "lifecycle_net_no_dhcp_2" {
  region         = "${var.region_name}"
  name           = "lifecycle-no-dhcp-2"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "lifecycle_subnet_no_dhcp_2" {
  region           = "${var.region_name}"
  network_id       = "${openstack_networking_network_v2.lifecycle_net_no_dhcp_2.id}"
  cidr             = "10.2.1.0/24"
  ip_version       = 4
  name             = "lifecycle-subnet-no-dhcp-2"
  gateway_ip       = "10.2.1.1"
  enable_dhcp      = "false"
  dns_nameservers = "${var.dns_nameservers}"
}

# router

resource "openstack_networking_router_interface_v2" "lifecycle_port" {
  region    = "${var.region_name}"
  router_id = "${var.default_router_id}"
  subnet_id = "${openstack_networking_subnet_v2.lifecycle_subnet.id}"
}

resource "openstack_networking_floatingip_v2" "lifecycle_floating_ip" {
  region = "${var.region_name}"
  pool   = "${var.ext_net_name}"
}

# lbaas

resource "openstack_lb_loadbalancer_v2" "lifecycle_loadbalancer" {
  vip_subnet_id = "${openstack_networking_subnet_v2.lifecycle_subnet.id}"
  name = "Lifecycle Load Balancer"
  loadbalancer_provider = "haproxy"
  count = "${var.use_lbaas == "true" ? 1 : 0}"
}

resource "openstack_lb_listener_v2" "lifecycle_listener" {
  protocol        = "TCP"
  protocol_port   = 4444
  name = "Lifecycle Listener"
  loadbalancer_id =  "${element(openstack_lb_loadbalancer_v2.lifecycle_loadbalancer.*.id, count.index)}"
  count = "${var.use_lbaas == "true" ? 1 : 0}"
}

resource "openstack_lb_pool_v2" "lifecycle_pool" {
  protocol    = "TCP"
  lb_method   = "ROUND_ROBIN"
  name = "Lifecycle Pool"
  listener_id = "${element(openstack_lb_listener_v2.lifecycle_listener.*.id, count.index)}"
  count = "${var.use_lbaas == "true" ? 1 : 0}"
}