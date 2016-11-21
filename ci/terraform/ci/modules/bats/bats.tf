variable "default_router_id" {}

variable "region_name" {
  description = "OpenStack region name"
}

variable "dns_nameservers" {
  description = "DNS server IPs"
}

variable "primary_net_name" {
  description = "OpenStack network name"
}

variable "primary_net_cidr" {
  description = "OpenStack primary network cidr"
}

variable "primary_net_allocation_pool_start" {
  description = "OpenStack network allocation pool start"
}

variable "primary_net_allocation_pool_end" {
  description = "OpenStack network allocation pool end"
}

variable "primary_net_gateway" {
  description = "OpenStack network gateway"
}


variable "ext_net_name" {
  description = "OpenStack external network name to register floating IP"
}

resource "openstack_networking_network_v2" "primary_net" {
  region         = "${var.region_name}"
  name           = "${var.primary_net_name}"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "primary_subnet" {
  region           = "${var.region_name}"
  network_id       = "${openstack_networking_network_v2.primary_net.id}"
  cidr             = "${var.primary_net_cidr}"
  ip_version       = 4
  name             = "${var.primary_net_name}-sub"
  allocation_pools = {
    start = "${var.primary_net_allocation_pool_start}"
    end   = "${var.primary_net_allocation_pool_end}"
  }
  gateway_ip       = "${var.primary_net_gateway}"
  enable_dhcp      = "true"
  dns_nameservers = ["${compact(split(",",var.dns_nameservers))}"]
}

resource "openstack_networking_router_interface_v2" "primary_port" {
  region    = "${var.region_name}"
  router_id = "${var.default_router_id}"
  subnet_id = "${openstack_networking_subnet_v2.primary_subnet.id}"
}

resource "openstack_compute_floatingip_v2" "floating_ip" {
  region = "${var.region_name}"
  pool   = "${var.ext_net_name}"
}

resource "openstack_compute_floatingip_v2" "director_public_ip" {
  region = "${var.region_name}"
  pool   = "${var.ext_net_name}"
}

output "primary_net_id" {
  value = "${openstack_networking_network_v2.primary_net.id}"
}

output "primary_net_cidr" {
  value = "${openstack_networking_subnet_v2.primary_subnet.cidr}"
}

output "primary_net_dhcp_pool" {
  value = "${openstack_networking_subnet_v2.primary_subnet.allocation_pools.0.start}-${openstack_networking_subnet_v2.primary_subnet.allocation_pools.0.end}"
}

output "primary_net_gateway" {
  value = "${openstack_networking_subnet_v2.primary_subnet.gateway_ip}"
}

output "primary_net_manual_ip" {
  value = "${cidrhost(openstack_networking_subnet_v2.primary_subnet.cidr, 4)}"
}

output "primary_net_second_manual_ip" {
  value = "${cidrhost(openstack_networking_subnet_v2.primary_subnet.cidr, 5)}"
}

output "primary_net_static_range" {
  value = "${cidrhost(openstack_networking_subnet_v2.primary_subnet.cidr, 4)}-${cidrhost(openstack_networking_subnet_v2.primary_subnet.cidr, 100)}"
}


output "director_floating_ip" {
  value = "${openstack_compute_floatingip_v2.floating_ip.address}"
}

output "director_private_ip" {
  value = "${cidrhost(openstack_networking_subnet_v2.primary_subnet.cidr, 3)}"
}

output "director_public_ip" {
  value = "${openstack_compute_floatingip_v2.director_public_ip.address}"
}

output "ubuntu_director_private_ip" {
  value = "${cidrhost(openstack_networking_subnet_v2.primary_subnet.cidr, 3)}"
}

