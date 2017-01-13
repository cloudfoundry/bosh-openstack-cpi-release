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

variable "region_name" {
  description = "OpenStack region name"
}

variable "prefix" {
  description = "A prefix representing the name this script is used for, .e.g. v3-e2e"
}

variable "default_public_key" {
  description = "This is the actual public key which is uploaded"
}

resource "openstack_compute_keypair_v2" "default_key" {
  region     = "${var.region_name}"
  name       = "${var.prefix}-${var.project_name}"
  public_key = "${var.default_public_key}"
}

resource "openstack_compute_secgroup_v2" "secgroup" {
  region      = "${var.region_name}"
  name        = "${var.prefix}"
  description = "e2e security group"

  rule {
    ip_protocol = "tcp"
    from_port   = "1"
    to_port     = "65535"
    cidr        = "0.0.0.0/0"
  }
}

output "secondary_openstack_security_group_name" {
  value = "${openstack_compute_secgroup_v2.secgroup.name}"
}

output "secondary_openstack_default_key_name" {
  value = "${openstack_compute_keypair_v2.default_key.name}"
}