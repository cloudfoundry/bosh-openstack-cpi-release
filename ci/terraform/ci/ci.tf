provider "openstack" {
  auth_url    = "${var.auth_url}"
  user_name   = "${var.user_name}"
  password    = "${var.password}"
  tenant_name = "${var.tenant_name}"
  domain_name = "${var.domain_name}"
  insecure    = "${var.insecure}"
}

module "base" {
  source = "github.com/cloudfoundry-incubator/bosh-openstack-cpi-release//ci/terraform/ci/modules/base"
  region_name = "${var.region_name}"
  tenant_name = "${var.tenant_name}"
  ext_net_id = "${var.ext_net_id}"
  ext_net_cidr = "${var.ext_net_cidr}"
  concourse_external_network_cidr = "${var.concourse_external_network_cidr}"
  openstack_default_key_public_key = "${var.openstack_default_key_public_key}"
  prefix = "ci"
  add_security_group = "1"
}

module "bats" {
  source = "github.com/cloudfoundry-incubator/bosh-openstack-cpi-release//ci/terraform/ci/modules/bats"
  region_name = "${var.region_name}"
  ext_net_name = "${var.ext_net_name}"
  dns_nameservers = "${var.dns_nameservers}"
  default_router_id = "${module.base.default_router_id}"
}

module "lifecycle" {
  source = "github.com/cloudfoundry-incubator/bosh-openstack-cpi-release//ci/terraform/ci/modules/lifecycle"
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
  default = ""
  description = "DNS server IPs"
}

variable "concourse_external_network_cidr" {
  description = "Network cidr where concourse is running in. Use value of ext_net_cidr, if it runs within OpenStack"
}

variable "openstack_default_key_public_key" {
  description = "This is the actual public key which is uploaded"
}

output "bats_dynamic_ubuntu_primary_net_id" {
  value = "${module.bats.bats_dynamic_ubuntu_primary_net_id}"
}

output "bats_dynamic_centos_primary_net_id" {
  value = "${module.bats.bats_dynamic_centos_primary_net_id}"
}

output "bats_manual_ubuntu_primary_net_id" {
  value = "${module.bats.bats_manual_ubuntu_primary_net_id}"
}

output "bats_manual_ubuntu_secondary_net_id" {
  value = "${module.bats.bats_manual_ubuntu_secondary_net_id}"
}

output "bats_manual_centos_primary_net_id" {
  value = "${module.bats.bats_manual_centos_primary_net_id}"
}

output "bats_manual_centos_secondary_net_id" {
  value = "${module.bats.bats_manual_centos_secondary_net_id}"
}

output "bats_dynamic_ubuntu_floating_ip" {
  value = "${module.bats.bats_dynamic_ubuntu_floating_ip}"
}

output "bats_dynamic_ubuntu_director_public_ip" {
  value = "${module.bats.bats_dynamic_ubuntu_director_public_ip}"
}

output "bats_dynamic_centos_director_public_ip" {
  value = "${module.bats.bats_dynamic_centos_director_public_ip}"
}

output "bats_dynamic_centos_floating_ip" {
  value = "${module.bats.bats_dynamic_centos_floating_ip}"
}

output "bats_manual_ubuntu_director_public_ip" {
  value = "${module.bats.bats_manual_ubuntu_director_public_ip}"
}

output "bats_manual_ubuntu_floating_ip" {
  value = "${module.bats.bats_manual_ubuntu_floating_ip}"
}

output "bats_manual_centos_director_public_ip" {
  value = "${module.bats.bats_manual_centos_director_public_ip}"
}

output "bats_manual_centos_floating_ip" {
  value = "${module.bats.bats_manual_centos_floating_ip}"
}

output "lifecycle_openstack_net_id" {
  value = "${module.lifecycle.lifecycle_openstack_net_id}"
}

output "lifecycle_manual_ip" {
  value = "${module.lifecycle.lifecycle_manual_ip}"
}

output "lifecycle_net_id_no_dhcp_1" {
  value = "${module.lifecycle.lifecycle_net_id_no_dhcp_1}"
}

output "lifecycle_no_dhcp_manual_ip_1" {
  value = "${module.lifecycle.lifecycle_no_dhcp_manual_ip_1}"
}

output "lifecycle_net_id_no_dhcp_2" {
  value = "${module.lifecycle.lifecycle_net_id_no_dhcp_2}"
}

output "lifecycle_no_dhcp_manual_ip_2" {
  value = "${module.lifecycle.lifecycle_no_dhcp_manual_ip_2}"
}

output "bats_manual_centos_director_private_ip" {
  value = "${module.bats.bats_manual_centos_director_private_ip}"
}

output "bats_manual_centos_primary_net_cidr" {
  value = "${module.bats.bats_manual_centos_primary_net_cidr}"
}

output "bats_manual_centos_primary_net_dhcp_pool" {
  value = "${module.bats.bats_manual_centos_primary_net_dhcp_pool}"
}

output "bats_manual_centos_primary_net_gateway" {
  value = "${module.bats.bats_manual_centos_primary_net_gateway}"
}

output "bats_manual_centos_primary_net_manual_ip" {
  value = "${module.bats.bats_manual_centos_primary_net_manual_ip}"
}

output "bats_manual_centos_primary_net_second_manual_ip" {
  value = "${module.bats.bats_manual_centos_primary_net_second_manual_ip}"
}

output "bats_manual_centos_primary_net_static_range" {
  value = "${module.bats.bats_manual_centos_primary_net_static_range}"
}

output "bats_manual_centos_secondary_net_cidr" {
  value = "${module.bats.bats_manual_centos_secondary_net_cidr}"
}

output "bats_manual_centos_secondary_net_dhcp_pool" {
  value = "${module.bats.bats_manual_centos_secondary_net_dhcp_pool}"
}

output "bats_manual_centos_secondary_net_gateway" {
  value = "${module.bats.bats_manual_centos_secondary_net_gateway}"
}

output "bats_manual_centos_secondary_net_manual_ip" {
  value = "${module.bats.bats_manual_centos_secondary_net_manual_ip}"
}

output "bats_manual_centos_secondary_net_static_range" {
  value = "${module.bats.bats_manual_centos_secondary_net_static_range}"
}

output "bats_manual_ubuntu_director_private_ip" {
  value = "${module.bats.bats_manual_ubuntu_director_private_ip}"
}

output "bats_manual_ubuntu_primary_net_cidr" {
  value = "${module.bats.bats_manual_ubuntu_primary_net_cidr}"
}

output "bats_manual_ubuntu_primary_net_dhcp_pool" {
  value = "${module.bats.bats_manual_ubuntu_primary_net_dhcp_pool}"
}

output "bats_manual_ubuntu_primary_net_gateway" {
  value = "${module.bats.bats_manual_ubuntu_primary_net_gateway}"
}

output "bats_manual_ubuntu_primary_net_manual_ip" {
  value = "${module.bats.bats_manual_ubuntu_primary_net_manual_ip}"
}

output "bats_manual_ubuntu_primary_net_second_manual_ip" {
  value = "${module.bats.bats_manual_ubuntu_primary_net_second_manual_ip}"
}

output "bats_manual_ubuntu_primary_net_static_range" {
  value = "${module.bats.bats_manual_ubuntu_primary_net_static_range}"
}

output "bats_manual_ubuntu_secondary_net_cidr" {
  value = "${module.bats.bats_manual_ubuntu_secondary_net_cidr}"
}

output "bats_manual_ubuntu_secondary_net_dhcp_pool" {
  value = "${module.bats.bats_manual_ubuntu_secondary_net_dhcp_pool}"
}

output "bats_manual_ubuntu_secondary_net_gateway" {
  value = "${module.bats.bats_manual_ubuntu_secondary_net_gateway}"
}

output "bats_manual_ubuntu_secondary_net_manual_ip" {
  value = "${module.bats.bats_manual_ubuntu_secondary_net_manual_ip}"
}

output "bats_manual_ubuntu_secondary_net_static_range" {
  value = "${module.bats.bats_manual_ubuntu_secondary_net_static_range}"
}

output "dns" {
  value = "${var.dns_nameservers}"
}

output "openstack_api_key" {
  value = "${var.password}"
}

output "openstack_tenant" {
  value = "${var.tenant_name}"
}

output "openstack_username" {
  value = "${var.user_name}"
}

output "lifecycle_openstack_domain" {
  value = "${var.domain_name}"
}

output "lifecycle_openstack_project" {
  value = "${var.tenant_name}"
}

output "lifecycle_openstack_tenant" {
  value = "${var.tenant_name}"
}

output "ci_key_name" {
  value = "${module.base.key_name}"
}