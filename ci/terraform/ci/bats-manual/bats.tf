provider "openstack" {
  auth_url    = var.auth_url
  user_name   = var.user_name
  password    = var.password
  tenant_name = var.project_name
  domain_name = var.domain_name
  insecure    = var.insecure
  cacert_file = var.cacert_file
}

module "base" {
  source                           = "../modules/base"
  region_name                      = var.region_name
  project_name                     = var.project_name
  ext_net_id                       = var.ext_net_id
  ext_net_cidr                     = var.ext_net_cidr
  concourse_external_network_cidr  = var.concourse_external_network_cidr
  openstack_default_key_public_key = var.openstack_default_key_public_key
  prefix                           = var.prefix
  add_security_group               = "1"
}

module "bats" {
  source                            = "../modules/bats"
  region_name                       = var.region_name
  primary_net_name                  = var.primary_net_name
  primary_net_cidr                  = var.primary_net_cidr
  primary_net_allocation_pool_start = var.primary_net_allocation_pool_start
  primary_net_allocation_pool_end   = var.primary_net_allocation_pool_end
  ext_net_name                      = var.ext_net_name
  dns_nameservers                   = var.dns_nameservers
  default_router_id                 = module.base.default_router_id
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
  default     = "false"
  description = "SSL certificate validation"
}

variable "cacert_file" {
  default     = ""
  description = "Path to trusted CA certificate for OpenStack in PEM format"
}

variable "region_name" {
  description = "OpenStack region name"
}

variable "primary_net_name" {
  description = "OpenStack primary network name"
}

variable "primary_net_cidr" {
  description = "OpenStack primary network cidr"
}

variable "primary_net_allocation_pool_start" {
  description = "OpenStack primary network allocation pool start"
}

variable "primary_net_allocation_pool_end" {
  description = "OpenStack primary network allocation pool end"
}

variable "secondary_net_name" {
  description = "OpenStack secondary network name"
}

variable "secondary_net_cidr" {
  description = "OpenStack secondary network cidr"
}

variable "secondary_net_allocation_pool_start" {
  description = "OpenStack secondary network allocation pool start"
}

variable "secondary_net_allocation_pool_end" {
  description = "OpenStack secondary network allocation pool end"
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
  description = "DNS server IPs"
  type        = list(string)
}

variable "concourse_external_network_cidr" {
  description = "Network cidr where concourse is running in. Use value of ext_net_cidr, if it runs within OpenStack"
}

variable "openstack_default_key_public_key" {
  description = "This is the actual public key which is uploaded"
}

variable "prefix" {
  description = "This is the prefix used to identify resources in each job, e.g. for the actual public key name"
}

resource "openstack_networking_network_v2" "secondary_net" {
  region         = var.region_name
  name           = var.secondary_net_name
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "secondary_subnet" {
  region     = var.region_name
  network_id = openstack_networking_network_v2.secondary_net.id
  cidr       = var.secondary_net_cidr
  ip_version = 4
  name       = "${var.secondary_net_name}-sub"
  allocation_pool {
    start = var.secondary_net_allocation_pool_start
    end   = var.secondary_net_allocation_pool_end
  }
  gateway_ip      = cidrhost(var.secondary_net_cidr, 1)
  enable_dhcp     = "true"
  dns_nameservers = var.dns_nameservers
}

resource "openstack_networking_router_interface_v2" "secondary_port" {
  region    = var.region_name
  router_id = module.base.default_router_id
  subnet_id = openstack_networking_subnet_v2.secondary_subnet.id
}

output "director_public_ip" {
  value = module.bats.director_public_ip
}

output "director_private_ip" {
  value = module.bats.director_private_ip
}

output "floating_ip" {
  value = module.bats.floating_ip
}

output "primary_net_id" {
  value = module.bats.primary_net_id
}

output "primary_net_cidr" {
  value = module.bats.primary_net_cidr
}

output "primary_net_dhcp_pool" {
  value = module.bats.primary_net_dhcp_pool
}

output "primary_net_gateway" {
  value = module.bats.primary_net_gateway
}

output "primary_net_manual_ip" {
  value = module.bats.primary_net_manual_ip
}

output "primary_net_second_manual_ip" {
  value = module.bats.primary_net_second_manual_ip
}

output "primary_net_static_range" {
  value = module.bats.primary_net_static_range
}

output "secondary_net_id" {
  value = openstack_networking_network_v2.secondary_net.id
}

output "secondary_net_cidr" {
  value = openstack_networking_subnet_v2.secondary_subnet.cidr
}

output "secondary_net_dhcp_pool" {
  value = "%{ for pool in openstack_networking_subnet_v2.secondary_subnet.allocation_pool[*] }${pool.start}-${pool.end}%{ endfor }"
}

output "secondary_net_gateway" {
  value = openstack_networking_subnet_v2.secondary_subnet.gateway_ip
}

output "secondary_net_manual_ip" {
  value = cidrhost(openstack_networking_subnet_v2.secondary_subnet.cidr, 4)
}

output "secondary_net_static_range" {
  value = "${cidrhost(openstack_networking_subnet_v2.secondary_subnet.cidr, 4)}-${cidrhost(openstack_networking_subnet_v2.secondary_subnet.cidr, 100)}"
}

output "dns" {
  value = var.dns_nameservers
}

output "openstack_project" {
  value = var.project_name
}

output "default_key_name" {
  value = module.base.key_name
}

output "security_group" {
  value = module.base.security_group
}
