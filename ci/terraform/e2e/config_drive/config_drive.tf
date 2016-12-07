module "base" {
  source                          = "../modules/base"
  auth_url                        = "${var.auth_url}"
  user_name                       = "${var.user_name}"
  password                        = "${var.password}"
  project_name                    = "${var.project_name}"
  domain_name                     = "${var.domain_name}"
  insecure                        = "${var.insecure}"
  dns_nameservers                 = "${var.dns_nameservers}"
  ext_net_name                    = "${var.ext_net_name}"
  ext_net_id                      = "${var.ext_net_id}"
  ext_net_cidr                    = "${var.ext_net_cidr}"
  region_name                     = "${var.region_name}"
  prefix                          = "${var.prefix}"
  concourse_external_network_cidr = "${var.concourse_external_network_cidr}"
  default_public_key              = "${var.default_public_key}"
  e2e_net_cidr                    = "${var.e2e_net_cidr}"
}

module "config_drive" {
  source                          = "../modules/config_drive"
  region_name                     = "${var.region_name}"
  auth_url                        = "${var.auth_url}"
  user_name                       = "${var.user_name}"
  password                        = "${var.password}"
  project_name                    = "${var.project_name}"
  domain_name                     = "${var.domain_name}"
  insecure                        = "${var.insecure}"
  dns_nameservers                 = "${var.dns_nameservers}"
  e2e_router_id                   = "${module.base.e2e_router_id}"
  no_dhcp_net_1_cidr              = "${var.no_dhcp_net_1_cidr}"
  no_dhcp_net_2_cidr              = "${var.no_dhcp_net_2_cidr}"
  prefix                          = "${var.prefix}"
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
  default = "v3-e2e"
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

variable "no_dhcp_net_1_cidr" {
  description = "OpenStack e2e network cidr 1 with DHCP disabled"
}

variable "no_dhcp_net_2_cidr" {
  description = "OpenStack e2e network cidr 2 with DHCP disabled"
}

output "network_no_dhcp_1_id" {
  value = "${module.config_drive.network_no_dhcp_1_id}"
}

output "network_no_dhcp_1_range" {
  value = "${module.config_drive.network_no_dhcp_1_range}"
}

output "network_no_dhcp_1_gateway" {
  value = "${module.config_drive.network_no_dhcp_1_gateway}"
}

output "network_no_dhcp_1_ip" {
  value = "${module.config_drive.network_no_dhcp_1_ip}"
}

output "network_no_dhcp_2_id" {
  value = "${module.config_drive.network_no_dhcp_2_id}"
}

output "network_no_dhcp_2_range" {
  value = "${module.config_drive.network_no_dhcp_2_range}"
}

output "network_no_dhcp_2_gateway" {
  value = "${module.config_drive.network_no_dhcp_2_gateway}"
}

output "network_no_dhcp_2_ip" {
  value = "${module.config_drive.network_no_dhcp_2_ip}"
}

output "v3_e2e_security_group" {
  value = "${module.base.v3_e2e_security_group}"
}

output "v3_e2e_net_id" {
  value = "${module.base.v3_e2e_net_id}"
}

output "v3_e2e_net_cidr" {
  value = "${module.base.v3_e2e_net_cidr}"
}

output "v3_e2e_net_gateway" {
  value = "${module.base.v3_e2e_net_gateway}"
}

output "e2e_router_id" {
  value = "${module.base.e2e_router_id}"
}

output "director_public_ip" {
  value = "${module.base.director_public_ip}"
}

output "director_private_ip" {
  value = "${module.base.director_private_ip}"
}

output "v3_e2e_default_key_name" {
  value = "${module.base.v3_e2e_default_key_name}"
}

output "dns" {
  value = "${module.base.dns}"
}