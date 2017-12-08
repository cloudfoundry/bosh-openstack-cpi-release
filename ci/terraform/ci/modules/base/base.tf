variable "prefix" {
  description = "A prefix representing the name this script is used for, .e.g. lifecycle"
}

variable "add_security_group" {
  description = "Set 1 to add security group, set 0 to not add it"
}

variable "project_name" {
  description = "OpenStack project/tenant name"
}

variable "region_name" {
  description = "OpenStack region name"
}

variable "ext_net_id" {
  description = "OpenStack external network id to create router interface port"
}

variable "ext_net_cidr" {
  description = "OpenStack external network cidr to define ingress security group rules"
}

variable "concourse_external_network_cidr" {
  description = "Network cidr where concourse is running in. Use value of ext_net_cidr, if it runs within OpenStack"
}

variable "openstack_default_key_public_key" {
  description = "This is the actual public key which is uploaded"
}

output "key_name" {
  value = "${openstack_compute_keypair_v2.openstack_compute_keypair_v2.name}"
}

output "default_router_id" {
  value = "${openstack_networking_router_v2.default_router.id}"
}

output "security_group" {
  value = "${openstack_networking_secgroup_v2.secgroup.*.name}"
}

# key pairs

resource "openstack_compute_keypair_v2" "openstack_compute_keypair_v2" {
  region     = "${var.region_name}"
  name       = "${var.prefix}-${var.project_name}"
  public_key = "${var.openstack_default_key_public_key}"
}

resource "openstack_networking_router_v2" "default_router" {
  region           = "${var.region_name}"
  name             = "${var.prefix}-router"
  admin_state_up   = "true"
  external_gateway = "${var.ext_net_id}"
}

resource "openstack_networking_secgroup_v2" "secgroup" {
  region      = "${var.region_name}"
  name        = "${var.prefix}"
  description = "security group"
  count       = "${var.add_security_group}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_1" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "tcp"
  remote_group_id = "${openstack_networking_secgroup_v2.secgroup.*.id}"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup.*.id}"
  count = "${var.add_security_group}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_2" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "udp"
  remote_group_id = "${openstack_networking_secgroup_v2.secgroup.*.id}"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup.*.id}"
  count = "${var.add_security_group}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_3" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "icmp"
  remote_group_id = "${openstack_networking_secgroup_v2.secgroup.*.id}"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup.*.id}"
  count = "${var.add_security_group}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_4" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "tcp"
  port_range_min = 22
  port_range_max = 22
  remote_ip_prefix = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup.*.id}"
  count = "${var.add_security_group}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_5" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "tcp"
  port_range_min = 25555
  port_range_max = 25555
  remote_ip_prefix = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup.*.id}"
  count = "${var.add_security_group}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_6" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "tcp"
  port_range_min = 6868
  port_range_max = 6868
  remote_ip_prefix = "${var.concourse_external_network_cidr}"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup.*.id}"
  count = "${var.add_security_group}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_7" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "udp"
  port_range_min = 53
  port_range_max = 53
  remote_ip_prefix = "${var.concourse_external_network_cidr}"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup.*.id}"
  count = "${var.add_security_group}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_8" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "tcp"
  port_range_min = 53
  port_range_max = 53
  remote_ip_prefix = "${var.concourse_external_network_cidr}"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup.*.id}"
  count = "${var.add_security_group}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_9" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "tcp"
  remote_ip_prefix = "${var.ext_net_cidr}"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup.*.id}"
  count = "${var.add_security_group}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_10" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "udp"
  remote_ip_prefix = "${var.ext_net_cidr}"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup.*.id}"
  count = "${var.add_security_group}"
}

