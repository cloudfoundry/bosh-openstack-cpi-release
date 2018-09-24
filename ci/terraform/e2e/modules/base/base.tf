provider "openstack" {
  auth_url    = "${var.auth_url}"
  user_name   = "${var.user_name}"
  password    = "${var.password}"
  tenant_name = "${var.project_name}"
  domain_name = "${var.domain_name}"
  insecure    = "${var.insecure}"
  cacert_file = "${var.cacert_file}"
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

variable "cacert_file" {
  default = ""
  description = "Path to trusted CA certificate for OpenStack in PEM format"
}

variable "project_name" {
  description = "OpenStack project/tenant name"
}

variable "dns_nameservers" {
   description = "List of DNS server IPs"
   type = "list"
}

variable "ext_net_name" {
  description = "OpenStack external network name to register floating IP"
}

variable "ext_net_id" {
  description = "OpenStack external network id to create router interface port"
}

variable "ext_net_cidr" {
  description = "OpenStack external network cidr"
}

variable "region_name" {
  description = "OpenStack region name"
}

variable "prefix" {
  description = "A prefix representing the name this script is used for, .e.g. v3-e2e"
}

variable "concourse_external_network_cidr" {
  description = "Network cidr where concourse is running in. Use external network cidr, if it runs within OpenStack"
}

variable "default_public_key" {
  description = "This is the actual public key which is uploaded"
}

variable "e2e_net_cidr" {
  description = "OpenStack e2e network cidr"
}

resource "openstack_compute_keypair_v2" "v3_e2e_default_key" {
  region     = "${var.region_name}"
  name       = "${var.prefix}-${var.project_name}"
  public_key = "${var.default_public_key}"
}

resource "openstack_networking_network_v2" "v3_e2e_net" {
  region         = "${var.region_name}"
  name           = "${var.prefix}-net"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "v3_e2e_subnet" {
  region           = "${var.region_name}"
  network_id       = "${openstack_networking_network_v2.v3_e2e_net.id}"
  cidr             = "${var.e2e_net_cidr}"
  ip_version       = 4
  name             = "${var.prefix}-subnet"
  allocation_pools = {
    start = "${cidrhost(var.e2e_net_cidr, 200)}"
    end   = "${cidrhost(var.e2e_net_cidr, 254)}"
  }
  gateway_ip       = "${cidrhost(var.e2e_net_cidr, 1)}"
  enable_dhcp      = "true"
  dns_nameservers = "${var.dns_nameservers}"
}

resource "openstack_networking_router_v2" "e2e_router" {
  region           = "${var.region_name}"
  name             = "${var.prefix}-router"
  admin_state_up   = "true"
  external_network_id = "${var.ext_net_id}"
}

resource "openstack_networking_router_interface_v2" "v3_e2e_port" {
  region    = "${var.region_name}"
  router_id = "${openstack_networking_router_v2.e2e_router.id}"
  subnet_id = "${openstack_networking_subnet_v2.v3_e2e_subnet.id}"
}

resource "openstack_networking_floatingip_v2" "director_public_ip" {
  region = "${var.region_name}"
  pool   = "${var.ext_net_name}"
}

resource "openstack_networking_secgroup_v2" "secgroup" {
  region      = "${var.region_name}"
  name        = "${var.prefix}"
  description = "e2e security group"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_1" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "tcp"
  remote_group_id = "${openstack_networking_secgroup_v2.secgroup.id}"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_2" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "udp"
  remote_group_id = "${openstack_networking_secgroup_v2.secgroup.id}"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_3" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "icmp"
  remote_group_id = "${openstack_networking_secgroup_v2.secgroup.id}"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_4" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "tcp"
  port_range_min = 22
  port_range_max = 22
  remote_ip_prefix = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_5" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "tcp"
  port_range_min = 25555
  port_range_max = 25555
  remote_ip_prefix = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_6" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "tcp"
  port_range_min = 6868
  port_range_max = 6868
  remote_ip_prefix = "${var.concourse_external_network_cidr}"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_7" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "tcp"
  remote_ip_prefix = "${var.ext_net_cidr}"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_8" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "udp"
  remote_ip_prefix = "${var.ext_net_cidr}"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup.id}"
}

output "v3_e2e_security_group" {
  value = "${openstack_networking_secgroup_v2.secgroup.name}"
}

output "v3_e2e_net_id" {
  value = "${openstack_networking_network_v2.v3_e2e_net.id}"
}

output "v3_e2e_net_cidr" {
  value = "${openstack_networking_subnet_v2.v3_e2e_subnet.cidr}"
}

output "v3_e2e_net_gateway" {
  value = "${openstack_networking_subnet_v2.v3_e2e_subnet.gateway_ip}"
}

output "director_public_ip" {
  value = "${openstack_networking_floatingip_v2.director_public_ip.address}"
}

output "v3_e2e_default_key_name" {
  value = "${openstack_compute_keypair_v2.v3_e2e_default_key.name}"
}

output "e2e_router_id" {
  value = "${openstack_networking_router_v2.e2e_router.id}"
}

output "director_private_ip" {
  value = "${cidrhost(openstack_networking_subnet_v2.v3_e2e_subnet.cidr, 3)}"
}

output "dns" {
  value = "${var.dns_nameservers}"
}
