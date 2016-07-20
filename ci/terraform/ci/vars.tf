# input variables

# access coordinates/credentials
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
  description = "OpenStack external network cidr to define ingress security group rules"
}

variable "concourse_external_network_cidr" {
  description = "Network cidr where concourse is running in. Use value of ext_net_cidr, if it runs within OpenStack"
}

# region/zone coordinates
variable "region_name" {
  description = "OpenStack region name"
}

variable "availability_zone" {
  description = "OpenStack availability zone name"
}

variable "openstack_default_key_name_prefix" {
  default = "external-cpi"
}

variable "openstack_default_key_public_key" {
}

output "net id:   lifecycle_openstack_net_id" {
  value = "${openstack_networking_network_v2.lifecycle_net.id}"
}

output "net id:   lifecycle_net_id_no_dhcp_1" {
  value = "${openstack_networking_network_v2.lifecycle_net_no_dhcp_1.id}"
}

output "net id:   lifecycle_net_id_no_dhcp_2" {
  value = "${openstack_networking_network_v2.lifecycle_net_no_dhcp_2.id}"
}

output "net id:   bats_dynamic_ubuntu_primary_net_id" {
  value = "${openstack_networking_network_v2.bats_dynamic_ubuntu_primary_net.id}"
}

output "net id:   bats_dynamic_centos_primary_net_id" {
  value = "${openstack_networking_network_v2.bats_dynamic_centos_primary_net.id}"
}

output "net id:   bats_manual_ubuntu_primary_net_id" {
  value = "${openstack_networking_network_v2.bats_manual_ubuntu_primary_net.id}"
}

output "net id:   bats_manual_ubuntu_secondary_net_id" {
  value = "${openstack_networking_network_v2.bats_manual_ubuntu_secondary_net.id}"
}

output "net id:   bats_manual_centos_primary_net_id" {
  value = "${openstack_networking_network_v2.bats_manual_centos_primary_net.id}"
}

output "net id:   bats_manual_centos_secondary_net_id" {
  value = "${openstack_networking_network_v2.bats_manual_centos_secondary_net.id}"
}

output "floating ip:   bats_dynamic_ubuntu_floating_ip" {
  value = "${openstack_compute_floatingip_v2.bats_dynamic_ubuntu_floating_ip.address}"
}

output "floating ip:   bats_dynamic_ubuntu_director_public_ip" {
  value = "${openstack_compute_floatingip_v2.bats_dynamic_ubuntu_director_public_ip.address}"
}

output "floating ip:   bats_dynamic_centos_director_public_ip" {
  value = "${openstack_compute_floatingip_v2.bats_dynamic_centos_director_public_ip.address}"
}

output "floating ip:   bats_dynamic_centos_floating_ip" {
  value = "${openstack_compute_floatingip_v2.bats_dynamic_centos_floating_ip.address}"
}

output "floating ip:   bats_manual_ubuntu_director_public_ip" {
  value = "${openstack_compute_floatingip_v2.bats_manual_ubuntu_director_public_ip.address}"
}

output "floating ip:   bats_manual_ubuntu_floating_ip" {
  value = "${openstack_compute_floatingip_v2.bats_manual_ubuntu_floating_ip.address}"
}

output "floating ip:   bats_manual_centos_director_public_ip" {
  value = "${openstack_compute_floatingip_v2.bats_manual_centos_director_public_ip.address}"
}

output "floating ip:   bats_manual_centos_floating_ip" {
  value = "${openstack_compute_floatingip_v2.bats_manual_centos_floating_ip.address}"
}

output "openstack_default_key_name" {
  value = "${openstack_compute_keypair_v2.openstack_default_key_name.name}"
}
