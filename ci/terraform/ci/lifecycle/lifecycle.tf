provider "openstack" {
  auth_url    = "${var.auth_url}"
  user_name   = "${var.user_name}"
  password    = "${var.password}"
  tenant_name = "${var.tenant_name}"
  domain_name = "${var.domain_name}"
  insecure    = "${var.insecure}"
}

module "base" {
  source = "../modules/base"
  region_name = "${var.region_name}"
  tenant_name = "${var.tenant_name}"
  availability_zone = "${var.availability_zone}"
  ext_net_name = "${var.ext_net_name}"
  ext_net_id = "${var.ext_net_id}"
  ext_net_cidr = "${var.ext_net_cidr}"
  concourse_external_network_cidr = "${var.concourse_external_network_cidr}"
  openstack_default_key_name_prefix = "${var.openstack_default_key_name_prefix}"
  openstack_default_key_public_key = "${var.openstack_default_key_public_key}"
}

module "lifecycle" {
  source = "../modules/lifecycle"
  region_name = "${var.region_name}"
  dns_nameservers = "${var.dns_nameservers}"
  default_router_id = "${module.base.default_router_id}"
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

variable "tenant_name" {
  description = "OpenStack project/tenant name"
}

variable "insecure" {
  default = "false"
  description = "SSL certificate validation"
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

variable "dns_nameservers" {
  type = "list"
  default = []
  description = "DNS server IPs"
}

variable "concourse_external_network_cidr" {
  description = "Network cidr where concourse is running in. Use value of ext_net_cidr, if it runs within OpenStack"
}

variable "openstack_default_key_name_prefix" {
  default = "external-cpi"
  description = "This prefix will be used as the base name of the generated key pair"
}

variable "openstack_default_key_public_key" {
  description = "This is the actual public key which is uploaded"
}

output "net id:   lifecycle_openstack_net_id" {
  value = "${module.lifecycle.lifecycle_openstack_net_id}"
}

output "manual ip:   lifecycle_manual_ip" {
  value = "${module.lifecycle.lifecycle_manual_ip}"
}

output "net id:   lifecycle_net_id_no_dhcp_1" {
  value = "${module.lifecycle.lifecycle_net_id_no_dhcp_1}"
}

output "manual ip:   lifecycle_no_dhcp_manual_ip_1" {
  value = "${module.lifecycle.lifecycle_no_dhcp_manual_ip_1}"
}

output "net id:   lifecycle_net_id_no_dhcp_2" {
  value = "${module.lifecycle.lifecycle_net_id_no_dhcp_2}"
}

output "manual ip:   lifecycle_no_dhcp_manual_ip_2" {
  value = "${module.lifecycle.lifecycle_no_dhcp_manual_ip_2}"
}

output "domain:   lifecycle_openstack_domain" {
  value = "${var.domain_name}"
}

output "project:   lifecycle_openstack_project" {
  value = "${var.tenant_name}"
}

output "tenant:   lifecycle_openstack_tenant" {
  value = "${var.tenant_name}"
}

output "key name:   lifecycle_openstack_default_key_name" {
  value = "${var.openstack_default_key_name_prefix}-${var.tenant_name}"
}