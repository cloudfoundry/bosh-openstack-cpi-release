provider "openstack" {
  auth_url    = "${var.auth_url}"
  user_name   = "${var.user_name}"
  password    = "${var.password}"
  tenant_name = "${var.tenant_name}"
  domain_name = "${var.domain_name}"
  insecure    = "${var.insecure}"
}

module "base" {
  source                          = "github.com/cloudfoundry-incubator/bosh-openstack-cpi-release//ci/terraform/e2e/modules/base"
  tenant_name                     = "${var.tenant_name}"
  dns_nameservers                 = "${var.dns_nameservers}"
  ext_net_name                    = "${var.ext_net_name}"
  ext_net_id                      = "${var.ext_net_id}"
  ext_net_cidr                    = "${var.ext_net_cidr}"
  region_name                     = "${var.region_name}"
  v3_e2e_default_key_name_prefix  = "${var.v3_e2e_default_key_name_prefix}"
  concourse_external_network_cidr = "${var.concourse_external_network_cidr}"
  v3_e2e_default_key_public_key   = "${var.v3_e2e_default_key_public_key}"
}

module "config_drive" {
  source                          = "github.com/cloudfoundry-incubator/bosh-openstack-cpi-release//ci/terraform/e2e/modules/config_drive"
  region_name                     = "${var.region_name}"
  dns_nameservers                 = "${var.dns_nameservers}"
  e2e_router_id                   = "${module.base.e2e_router_id}"
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

variable "tenant_name" {
  description = "OpenStack project/tenant name"
}

variable "dns_nameservers" {
   default = ""
   description = "Comma-separated list of DNS server IPs"
}

# external network coordinates
variable "ext_net_name" {
  description = "OpenStack external network name to register floating IP"
}

variable "ext_net_id" {
  description = "OpenStack external network id to create router interface port"
}

variable "ext_net_cidr" {
  description = "OpenStack external network cidr"
}

# region/zone coordinates
variable "region_name" {
  description = "OpenStack region name"
}

variable "v3_e2e_default_key_name_prefix" {
  default = "v3-e2e"
}

variable "concourse_external_network_cidr" {
  description = "Network cidr where concourse is running in. Use external network cidr, if it runs within OpenStack"
}

variable "v3_e2e_default_key_public_key" {
}

output "v3_e2e_net_no_dhcp_1_id" {
  value = "${module.config_drive.v3_e2e_net_no_dhcp_1_id}"
}

output "v3_e2e_net_no_dhcp_2_id" {
  value = "${module.config_drive.v3_e2e_net_no_dhcp_2_id}"
}

output "v3_e2e_net_id" {
  value = "${module.base.v3_e2e_net_id}"
}

output "v3_e2e_director_floating_ip" {
  value = "${module.base.v3_e2e_director_floating_ip}"
}

output "v3_e2e_default_key_name" {
  value = "${module.base.v3_e2e_default_key_name}"
}
