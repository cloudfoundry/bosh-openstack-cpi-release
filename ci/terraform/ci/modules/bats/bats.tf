variable "default_router_id" {}

variable "region_name" {
  description = "OpenStack region name"
}

variable "dns_nameservers" {
  type = "list"
  description = "DNS server IPs"
}

variable "ext_net_name" {
  description = "OpenStack external network name to register floating IP"
}

resource "openstack_networking_network_v2" "bats_dynamic_ubuntu_primary_net" {
  region         = "${var.region_name}"
  name           = "bats-dynamic-ubuntu-primary"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "bats_dynamic_ubuntu_primary_subnet" {
  region           = "${var.region_name}"
  network_id       = "${openstack_networking_network_v2.bats_dynamic_ubuntu_primary_net.id}"
  cidr             = "10.0.2.0/24"
  ip_version       = 4
  name             = "bats-dynamic-ubuntu-primary-sub"
  allocation_pools = {
    start = "10.0.2.200"
    end   = "10.0.2.254"
  }
  gateway_ip       = "10.0.2.1"
  enable_dhcp      = "true"
  dns_nameservers = "${var.dns_nameservers}"
}

resource "openstack_networking_network_v2" "bats_dynamic_centos_primary_net" {
  region         = "${var.region_name}"
  name           = "bats-dynamic-centos-primary"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "bats_dynamic_centos_primary_subnet" {
  region           = "${var.region_name}"
  network_id       = "${openstack_networking_network_v2.bats_dynamic_centos_primary_net.id}"
  cidr             = "10.0.3.0/24"
  ip_version       = 4
  name             = "bats-dynamic-centos-primary-sub"
  allocation_pools = {
    start = "10.0.3.200"
    end   = "10.0.3.254"
  }
  gateway_ip       = "10.0.3.1"
  enable_dhcp      = "true"
  dns_nameservers = "${var.dns_nameservers}"
}

resource "openstack_networking_network_v2" "bats_manual_ubuntu_primary_net" {
  region         = "${var.region_name}"
  name           = "bats-manual-ubuntu-primary"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "bats_manual_ubuntu_primary_subnet" {
  region           = "${var.region_name}"
  network_id       = "${openstack_networking_network_v2.bats_manual_ubuntu_primary_net.id}"
  cidr             = "10.0.4.0/24"
  ip_version       = 4
  name             = "bats-manual-ubuntu-primary-sub"
  allocation_pools = {
    start = "10.0.4.200"
    end   = "10.0.4.254"
  }
  gateway_ip       = "10.0.4.1"
  enable_dhcp      = "true"
  dns_nameservers = "${var.dns_nameservers}"
}

resource "openstack_networking_network_v2" "bats_manual_ubuntu_secondary_net" {
  region         = "${var.region_name}"
  name           = "bats-manual-ubuntu-secondary"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "bats_manual_ubuntu_secondary_subnet" {
  region           = "${var.region_name}"
  network_id       = "${openstack_networking_network_v2.bats_manual_ubuntu_secondary_net.id}"
  cidr             = "10.0.5.0/24"
  ip_version       = 4
  name             = "bats-manual-ubuntu-secondary-sub"
  allocation_pools = {
    start = "10.0.5.200"
    end   = "10.0.5.254"
  }
  gateway_ip       = "10.0.5.1"
  enable_dhcp      = "true"
  dns_nameservers = "${var.dns_nameservers}"
}

resource "openstack_networking_network_v2" "bats_manual_centos_primary_net" {
  region         = "${var.region_name}"
  name           = "bats-manual-centos-primary"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "bats_manual_centos_primary_subnet" {
  region           = "${var.region_name}"
  network_id       = "${openstack_networking_network_v2.bats_manual_centos_primary_net.id}"
  cidr             = "10.0.6.0/24"
  ip_version       = 4
  name             = "bats-manual-centos-primary-sub"
  allocation_pools = {
    start = "10.0.6.200"
    end   = "10.0.6.254"
  }
  gateway_ip       = "10.0.6.1"
  enable_dhcp      = "true"
  dns_nameservers = "${var.dns_nameservers}"
}

resource "openstack_networking_network_v2" "bats_manual_centos_secondary_net" {
  region         = "${var.region_name}"
  name           = "bats-manual-centos-secondary"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "bats_manual_centos_secondary_subnet" {
  region           = "${var.region_name}"
  network_id       = "${openstack_networking_network_v2.bats_manual_centos_secondary_net.id}"
  cidr             = "10.0.7.0/24"
  ip_version       = 4
  name             = "bats-manual-centos-secondary-sub"
  allocation_pools = {
    start = "10.0.7.200"
    end   = "10.0.7.254"
  }
  gateway_ip       = "10.0.7.1"
  enable_dhcp      = "true"
  dns_nameservers = "${var.dns_nameservers}"
}

resource "openstack_networking_router_interface_v2" "bats_dynamic_ubuntu_primary_port" {
  region    = "${var.region_name}"
  router_id = "${var.default_router_id}"
  subnet_id = "${openstack_networking_subnet_v2.bats_dynamic_ubuntu_primary_subnet.id}"
}

resource "openstack_networking_router_interface_v2" "bats_dynamic_centos_primary_port" {
  region    = "${var.region_name}"
  router_id = "${var.default_router_id}"
  subnet_id = "${openstack_networking_subnet_v2.bats_dynamic_centos_primary_subnet.id}"
}

resource "openstack_networking_router_interface_v2" "bats_manual_ubuntu_primary_port" {
  region    = "${var.region_name}"
  router_id = "${var.default_router_id}"
  subnet_id = "${openstack_networking_subnet_v2.bats_manual_ubuntu_primary_subnet.id}"
}

resource "openstack_networking_router_interface_v2" "bats_manual_ubuntu_secondary_port" {
  region    = "${var.region_name}"
  router_id = "${var.default_router_id}"
  subnet_id = "${openstack_networking_subnet_v2.bats_manual_ubuntu_secondary_subnet.id}"
}

resource "openstack_networking_router_interface_v2" "bats_manual_centos_primary_port" {
  region    = "${var.region_name}"
  router_id = "${var.default_router_id}"
  subnet_id = "${openstack_networking_subnet_v2.bats_manual_centos_primary_subnet.id}"
}

resource "openstack_networking_router_interface_v2" "bats_manual_centos_secondary_port" {
  region    = "${var.region_name}"
  router_id = "${var.default_router_id}"
  subnet_id = "${openstack_networking_subnet_v2.bats_manual_centos_secondary_subnet.id}"
}

# floating ips

resource "openstack_compute_floatingip_v2" "bats_dynamic_ubuntu_floating_ip" {
  region = "${var.region_name}"
  pool   = "${var.ext_net_name}"
}

resource "openstack_compute_floatingip_v2" "bats_dynamic_ubuntu_director_public_ip" {
  region = "${var.region_name}"
  pool   = "${var.ext_net_name}"
}

resource "openstack_compute_floatingip_v2" "bats_dynamic_centos_director_public_ip" {
  region = "${var.region_name}"
  pool   = "${var.ext_net_name}"
}

resource "openstack_compute_floatingip_v2" "bats_dynamic_centos_floating_ip" {
  region = "${var.region_name}"
  pool   = "${var.ext_net_name}"
}

resource "openstack_compute_floatingip_v2" "bats_manual_ubuntu_director_public_ip" {
  region = "${var.region_name}"
  pool   = "${var.ext_net_name}"
}

resource "openstack_compute_floatingip_v2" "bats_manual_ubuntu_floating_ip" {
  region = "${var.region_name}"
  pool   = "${var.ext_net_name}"
}

resource "openstack_compute_floatingip_v2" "bats_manual_centos_director_public_ip" {
  region = "${var.region_name}"
  pool   = "${var.ext_net_name}"
}


resource "openstack_compute_floatingip_v2" "bats_manual_centos_floating_ip" {
  region = "${var.region_name}"
  pool   = "${var.ext_net_name}"
}

output "bats_dynamic_ubuntu_primary_net_id" {
  value = "${openstack_networking_network_v2.bats_dynamic_ubuntu_primary_net.id}"
}

output "bats_dynamic_centos_primary_net_id" {
  value = "${openstack_networking_network_v2.bats_dynamic_centos_primary_net.id}"
}

output "bats_manual_ubuntu_primary_net_id" {
  value = "${openstack_networking_network_v2.bats_manual_ubuntu_primary_net.id}"
}

output "bats_manual_ubuntu_secondary_net_id" {
  value = "${openstack_networking_network_v2.bats_manual_ubuntu_secondary_net.id}"
}

output "bats_manual_centos_primary_net_id" {
  value = "${openstack_networking_network_v2.bats_manual_centos_primary_net.id}"
}

output "bats_manual_centos_secondary_net_id" {
  value = "${openstack_networking_network_v2.bats_manual_centos_secondary_net.id}"
}

output "bats_dynamic_ubuntu_floating_ip" {
  value = "${openstack_compute_floatingip_v2.bats_dynamic_ubuntu_floating_ip.address}"
}

output "bats_dynamic_ubuntu_director_public_ip" {
  value = "${openstack_compute_floatingip_v2.bats_dynamic_ubuntu_director_public_ip.address}"
}

output "bats_dynamic_centos_director_public_ip" {
  value = "${openstack_compute_floatingip_v2.bats_dynamic_centos_director_public_ip.address}"
}

output "bats_dynamic_centos_floating_ip" {
  value = "${openstack_compute_floatingip_v2.bats_dynamic_centos_floating_ip.address}"
}

output "bats_manual_ubuntu_director_public_ip" {
  value = "${openstack_compute_floatingip_v2.bats_manual_ubuntu_director_public_ip.address}"
}

output "bats_manual_ubuntu_floating_ip" {
  value = "${openstack_compute_floatingip_v2.bats_manual_ubuntu_floating_ip.address}"
}

output "bats_manual_centos_director_public_ip" {
  value = "${openstack_compute_floatingip_v2.bats_manual_centos_director_public_ip.address}"
}

output "bats_manual_centos_floating_ip" {
  value = "${openstack_compute_floatingip_v2.bats_manual_centos_floating_ip.address}"
}
