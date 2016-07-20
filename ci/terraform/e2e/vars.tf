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
  description = "OpenStack external network cidr"
}

# region/zone coordinates
variable "region_name" {
  description = "OpenStack region name"
}

variable "availability_zone" {
  description = "OpenStack availability zone name"
}

variable "v3_e2e_default_key_name_prefix" {
  default = "v3-e2e"
}

variable "concourse_external_network_cidr" {
  description = "Network cidr where concourse is running in. Use external network cidr, if it runs within OpenStack"
}

variable "v3_e2e_default_key_public_key" {
}


output "net id:   v3_e2e_net_id" {
  value = "${openstack_networking_network_v2.v3_e2e_net.id}"
}

output "net id:   v3_e2e_net_no_dhcp_1_id" {
  value = "${openstack_networking_network_v2.v3_e2e_no_dhcp_1_net.id}"
}

output "net id:   v3_e2e_net_no_dhcp_2_id" {
  value = "${openstack_networking_network_v2.v3_e2e_no_dhcp_2_net.id}"
}

output "floating ip:   v3_e2e_ubuntu_director_floating_ip" {
  value = "${openstack_compute_floatingip_v2.v3_e2e_ubuntu_director_floating_ip.address}"
}

output "floating ip:   v3_e2e_centos_director_floating_ip" {
  value = "${openstack_compute_floatingip_v2.v3_e2e_centos_director_floating_ip.address}"
}

output "floating ip:   v3_e2e_ubuntu_config_drive_floating_ip" {
  value = "${openstack_compute_floatingip_v2.v3_e2e_ubuntu_config_drive_floating_ip.address}"
}

output "floating ip:   v3_e2e_centos_config_drive_floating_ip" {
  value = "${openstack_compute_floatingip_v2.v3_e2e_centos_config_drive_floating_ip.address}"
}

output "floating ip:   v3_ubuntu_upgrade_director_floating_ip" {
  value = "${openstack_compute_floatingip_v2.v3_ubuntu_upgrade_director_floating_ip.address}"
}

output "floating ip:   v3_centos_upgrade_director_floating_ip" {
  value = "${openstack_compute_floatingip_v2.v3_centos_upgrade_director_floating_ip.address}"
}

output "v3_e2e_default_key_name" {
  value = "${openstack_compute_keypair_v2.v3_e2e_default_key_name.name}"
}
