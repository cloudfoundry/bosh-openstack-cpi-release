variable "tenant_name" {
  description = "OpenStack tenant name"
}

variable "region_name" {
  description = "OpenStack region name"
}

variable "availability_zone" {
  description = "OpenStack availability zone name"
}
variable "ext_net_name" {
  description = "OpenStack external network name to register floating IP"
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

variable "openstack_default_key_name_prefix" {
  description = "This prefix will be used as the base name of the generated key pair"
}

variable "openstack_default_key_public_key" {
  description = "This is the actual public key which is uploaded"
}

output "default_router_id" {
  value = "${openstack_networking_router_v2.default_router.id}"
}

# key pairs

resource "openstack_compute_keypair_v2" "openstack_default_key_name" {
  region     = "${var.region_name}"
  name       = "${var.openstack_default_key_name_prefix}-${var.tenant_name}"
  public_key = "${var.openstack_default_key_public_key}"
}

resource "openstack_networking_router_v2" "default_router" {
  region           = "${var.region_name}"
  name             = "cpi-router"
  admin_state_up   = "true"
  external_gateway = "${var.ext_net_id}"
}

resource "openstack_compute_secgroup_v2" "ci_secgroup" {
  region      = "${var.region_name}"
  name        = "ci"
  description = "ci security group"

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
