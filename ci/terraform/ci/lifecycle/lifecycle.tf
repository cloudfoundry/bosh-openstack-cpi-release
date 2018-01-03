provider "openstack" {
  auth_url    = "${var.auth_url}"
  user_name   = "${var.user_name}"
  password    = "${var.password}"
  tenant_name = "${var.project_name}"
  domain_name = "${var.domain_name}"
  insecure    = "${var.insecure}"
  cacert_file = "${var.cacert_file}"
}

module "base" {
  source = "../modules/base"
  region_name = "${var.region_name}"
  project_name = "${var.project_name}"
  ext_net_id = "${var.ext_net_id}"
  ext_net_cidr = ""
  concourse_external_network_cidr = ""
  openstack_default_key_public_key = "${var.openstack_default_key_public_key}"
  prefix = "lifecycle"
  add_security_group = "0"
}

module "lifecycle" {
  source = "../modules/lifecycle"
  region_name = "${var.region_name}"
  dns_nameservers = "${var.dns_nameservers}"
  default_router_id = "${module.base.default_router_id}"
  ext_net_name = "${var.ext_net_name}"
  use_lbaas = "${var.use_lbaas}"
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

variable "project_name" {
  description = "OpenStack project/tenant name"
}

variable "insecure" {
  default = "false"
  description = "SSL certificate validation"
}

variable "cacert_file" {
  default = ""
  description = "Path to trusted CA certificate for OpenStack in PEM format"
}

variable "region_name" {
  description = "OpenStack region name"
}

variable "ext_net_id" {
  description = "OpenStack external network id to create router interface port"
}

variable "ext_net_name" {
  description = "OpenStack external network name to create router interface port"
}

variable "dns_nameservers" {
  default = ""
  description = "DNS server IPs"
}

variable "openstack_default_key_public_key" {
  description = "This is the actual public key which is uploaded"
}

variable "use_lbaas" {
  default = "false"
  description = "When set to 'true', all necessary LBaaS V2 resources are created."
}

output "net_id" {
  value = "${module.lifecycle.lifecycle_openstack_net_id}"
}

output "manual_ip" {
  value = "${module.lifecycle.lifecycle_manual_ip}"
}

output "allowed_address_pairs" {
  value = "${module.lifecycle.lifecycle_allowed_address_pairs}"
}

output "net_id_no_dhcp_1" {
  value = "${module.lifecycle.lifecycle_net_id_no_dhcp_1}"
}

output "no_dhcp_manual_ip_1" {
  value = "${module.lifecycle.lifecycle_no_dhcp_manual_ip_1}"
}

output "net_id_no_dhcp_2" {
  value = "${module.lifecycle.lifecycle_net_id_no_dhcp_2}"
}

output "no_dhcp_manual_ip_2" {
  value = "${module.lifecycle.lifecycle_no_dhcp_manual_ip_2}"
}

output "auth_url_v3" {
  value = "${var.auth_url}"
}

output "domain" {
  value = "${var.domain_name}"
}

output "project" {
  value = "${var.project_name}"
}

output "default_key_name" {
  value = "${module.base.key_name}"
}

output "floating_ip" {
  value = "${module.lifecycle.lifecycle_floating_ip}"
}

output "loadbalancer_pool_name" {
  value = "${module.lifecycle.lifecycle_lb_pool_name}"
}
