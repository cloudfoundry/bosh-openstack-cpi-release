provider "openstack" {
  auth_url    = "${var.auth_url}"
  user_name   = "${var.user_name}"
  password    = "${var.password}"
  tenant_name = "${var.project_name}"
  domain_name = "${var.domain_name}"
  insecure    = "${var.insecure}"
}

variable "auth_url" {
  description = "Authentication endpoint URL for OpenStack provider (only scheme+host+port, but without path!)"
}

variable "domain_name" {
  description = "OpenStack domain name"
}

variable "user_name" {
  description = "OpenStack pipeline technical user name"
}

variable "password" {
  description = "OpenStack user password"
}

variable "insecure" {
  default = "false"
  description = "SSL certificate validation"
}

variable "project_name" {
  description = "OpenStack project/tenant name"
}

variable "dns_nameservers" {
   default = ""
   description = "Comma-separated list of DNS server IPs"
}

variable "region_name" {
  description = "OpenStack region name"
}

variable "e2e_router_id" {
}

variable "no_dhcp_net_1_cidr" {
  description = "OpenStack e2e network cidr 1 with DHCP disabled"
}

variable "no_dhcp_net_2_cidr" {
  description = "OpenStack e2e network cidr 2 with DHCP disabled"
}

variable "prefix" {
  description = "A prefix representing the name this script is used for, .e.g. v3-e2e"
}

resource "openstack_networking_network_v2" "v3_e2e_no_dhcp_1_net" {
  region         = "${var.region_name}"
  name           = "${var.prefix}-no-dhcp-1-net"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "v3_e2e_no_dhcp_1_subnet" {
  region           = "${var.region_name}"
  network_id       = "${openstack_networking_network_v2.v3_e2e_no_dhcp_1_net.id}"
  cidr             = "${var.no_dhcp_net_1_cidr}"
  ip_version       = 4
  name             = "${var.prefix}-no-dhcp-1-subnet"
  allocation_pools = {
    start = "${cidrhost(var.no_dhcp_net_1_cidr, 200)}"
    end   = "${cidrhost(var.no_dhcp_net_1_cidr, 254)}"
  }
  gateway_ip       = "${cidrhost(var.no_dhcp_net_1_cidr, 1)}"
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
  cidr             = "${var.no_dhcp_net_2_cidr}"
  ip_version       = 4
  name             = "${var.prefix}-no-dhcp-2-subnet"
  allocation_pools = {
    start = "${cidrhost(var.no_dhcp_net_2_cidr, 200)}"
    end   = "${cidrhost(var.no_dhcp_net_2_cidr, 254)}"
  }
  gateway_ip       = "${cidrhost(var.no_dhcp_net_2_cidr, 1)}"
  enable_dhcp      = "false"
  dns_nameservers = ["${compact(split(",",var.dns_nameservers))}"]
}

resource "openstack_networking_router_interface_v2" "v3_e2e_no_dhcp_2_port" {
  region    = "${var.region_name}"
  router_id = "${var.e2e_router_id}"
  subnet_id = "${openstack_networking_subnet_v2.v3_e2e_no_dhcp_2_subnet.id}"
}

output "network_no_dhcp_1_id" {
  value = "${openstack_networking_network_v2.v3_e2e_no_dhcp_1_net.id}"
}

output "network_no_dhcp_1_range" {
  value = "${openstack_networking_subnet_v2.v3_e2e_no_dhcp_1_subnet.cidr}"
}

output "network_no_dhcp_1_gateway" {
  value = "${openstack_networking_subnet_v2.v3_e2e_no_dhcp_1_subnet.gateway_ip}"
}

output "network_no_dhcp_1_ip" {
  value = "${cidrhost(var.no_dhcp_net_1_cidr, 4)}"
}

output "network_no_dhcp_2_id" {
  value = "${openstack_networking_network_v2.v3_e2e_no_dhcp_2_net.id}"
}

output "network_no_dhcp_2_range" {
  value = "${openstack_networking_subnet_v2.v3_e2e_no_dhcp_2_subnet.cidr}"
}

output "network_no_dhcp_2_gateway" {
  value = "${openstack_networking_subnet_v2.v3_e2e_no_dhcp_2_subnet.gateway_ip}"
}

output "network_no_dhcp_2_ip" {
  value = "${cidrhost(var.no_dhcp_net_2_cidr, 4)}"
}