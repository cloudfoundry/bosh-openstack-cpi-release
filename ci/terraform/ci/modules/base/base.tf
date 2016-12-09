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
  value = "${openstack_compute_secgroup_v2.ci_secgroup.name}"
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

resource "openstack_compute_secgroup_v2" "ci_secgroup" {
  region      = "${var.region_name}"
  name        = "${var.prefix}"
  description = "security group"
  count = "${var.add_security_group}"

  # Allow anything from own sec group (Any was not possible)

  rule {
    ip_protocol = "tcp"
    from_port   = "1"
    to_port     = "65535"
    self        = true
  }

  rule {
    ip_protocol = "udp"
    from_port   = "1"
    to_port     = "65535"
    self        = true
  }

  rule {
    ip_protocol = "icmp"
    from_port   = "-1"
    to_port     = "-1"
    self        = true
  }

  rule {
    ip_protocol = "tcp"
    from_port   = "22"
    to_port     = "22"
    cidr        = "0.0.0.0/0"
  }

  rule {
    ip_protocol = "tcp"
    from_port   = "25555"
    to_port     = "25555"
    cidr        = "0.0.0.0/0"
  }

  rule {
    ip_protocol = "tcp"
    from_port   = "6868"
    to_port     = "6868"
    cidr        = "${var.concourse_external_network_cidr}"
  }

  rule {
    ip_protocol = "udp"
    from_port   = "53"
    to_port     = "53"
    cidr        = "${var.concourse_external_network_cidr}"
  }

  rule {
    ip_protocol = "tcp"
    from_port   = "53"
    to_port     = "53"
    cidr        = "${var.concourse_external_network_cidr}"
  }

  rule {
    ip_protocol = "tcp"
    from_port   = "1"
    to_port     = "65535"
    cidr        = "${var.ext_net_cidr}"
  }

  rule {
    ip_protocol = "udp"
    from_port   = "1"
    to_port     = "65535"
    cidr        = "${var.ext_net_cidr}"
  }
}
