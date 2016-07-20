# provider configuration

provider "openstack" {
  auth_url    = "${var.auth_url}"
  user_name   = "${var.user_name}"
  password    = "${var.password}"
  tenant_name = "${var.tenant_name}"
  domain_name = "${var.domain_name}"
  insecure    = "${var.insecure}"
}

# key pairs

resource "openstack_compute_keypair_v2" "openstack_default_key_name" {
  region     = "${var.region_name}"
  name       = "${var.openstack_default_key_name_prefix}-${var.tenant_name}"
  public_key = "${var.openstack_default_key_public_key}"
}

# networks

resource "openstack_networking_network_v2" "lifecycle_net" {
  region         = "${var.region_name}"
  name           = "lifecycle"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "lifecycle_subnet" {
  region           = "${var.region_name}"
  network_id       = "${openstack_networking_network_v2.lifecycle_net.id}"
  cidr             = "10.0.1.0/24"
  ip_version       = 4
  name             = "lifecycle_sub"
  allocation_pools = {
    start = "10.0.1.200"
    end   = "10.0.1.254"
  }
  gateway_ip       = "10.0.1.1"
  enable_dhcp      = "true"
  dns_nameservers = ["${compact(split(",",var.dns_nameservers))}"]
}

resource "openstack_networking_network_v2" "lifecycle_net_no_dhcp_1" {
  region         = "${var.region_name}"
  name           = "lifecycle-no-dhcp-1"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "lifecycle_subnet_no_dhcp_1" {
  region           = "${var.region_name}"
  network_id       = "${openstack_networking_network_v2.lifecycle_net_no_dhcp_1.id}"
  cidr             = "10.1.1.0/24"
  ip_version       = 4
  name             = "lifecycle-subnet-no-dhcp-1"
  gateway_ip       = "10.1.1.1"
  enable_dhcp      = "false"
  dns_nameservers = ["${compact(split(",",var.dns_nameservers))}"]
}

resource "openstack_networking_network_v2" "lifecycle_net_no_dhcp_2" {
  region         = "${var.region_name}"
  name           = "lifecycle-no-dhcp-2"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "lifecycle_subnet_no_dhcp_2" {
  region           = "${var.region_name}"
  network_id       = "${openstack_networking_network_v2.lifecycle_net_no_dhcp_2.id}"
  cidr             = "10.2.1.0/24"
  ip_version       = 4
  name             = "lifecycle-subnet-no-dhcp-2"
  gateway_ip       = "10.2.1.1"
  enable_dhcp      = "false"
  dns_nameservers = ["${compact(split(",",var.dns_nameservers))}"]
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
  dns_nameservers = ["${compact(split(",",var.dns_nameservers))}"]
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
  dns_nameservers = ["${compact(split(",",var.dns_nameservers))}"]
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
  dns_nameservers = ["${compact(split(",",var.dns_nameservers))}"]
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
  dns_nameservers = ["${compact(split(",",var.dns_nameservers))}"]
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
  dns_nameservers = ["${compact(split(",",var.dns_nameservers))}"]
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
  dns_nameservers = ["${compact(split(",",var.dns_nameservers))}"]
}

# router

resource "openstack_networking_router_v2" "default_router" {
  region           = "${var.region_name}"
  name             = "cpi-router"
  admin_state_up   = "true"
  external_gateway = "${var.ext_net_id}"
}

resource "openstack_networking_router_interface_v2" "lifecycle_port" {
  region    = "${var.region_name}"
  router_id = "${openstack_networking_router_v2.default_router.id}"
  subnet_id = "${openstack_networking_subnet_v2.lifecycle_subnet.id}"
}

resource "openstack_networking_router_interface_v2" "bats_dynamic_ubuntu_primary_port" {
  region    = "${var.region_name}"
  router_id = "${openstack_networking_router_v2.default_router.id}"
  subnet_id = "${openstack_networking_subnet_v2.bats_dynamic_ubuntu_primary_subnet.id}"
}

resource "openstack_networking_router_interface_v2" "bats_dynamic_centos_primary_port" {
  region    = "${var.region_name}"
  router_id = "${openstack_networking_router_v2.default_router.id}"
  subnet_id = "${openstack_networking_subnet_v2.bats_dynamic_centos_primary_subnet.id}"
}

resource "openstack_networking_router_interface_v2" "bats_manual_ubuntu_primary_port" {
  region    = "${var.region_name}"
  router_id = "${openstack_networking_router_v2.default_router.id}"
  subnet_id = "${openstack_networking_subnet_v2.bats_manual_ubuntu_primary_subnet.id}"
}

resource "openstack_networking_router_interface_v2" "bats_manual_ubuntu_secondary_port" {
  region    = "${var.region_name}"
  router_id = "${openstack_networking_router_v2.default_router.id}"
  subnet_id = "${openstack_networking_subnet_v2.bats_manual_ubuntu_secondary_subnet.id}"
}

resource "openstack_networking_router_interface_v2" "bats_manual_centos_primary_port" {
  region    = "${var.region_name}"
  router_id = "${openstack_networking_router_v2.default_router.id}"
  subnet_id = "${openstack_networking_subnet_v2.bats_manual_centos_primary_subnet.id}"
}

resource "openstack_networking_router_interface_v2" "bats_manual_centos_secondary_port" {
  region    = "${var.region_name}"
  router_id = "${openstack_networking_router_v2.default_router.id}"
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

resource "openstack_compute_secgroup_v2" "ci_secgroup" {
  region      = "${var.region_name}"
  name        = "ci"
  description = "ci security group"

  # Allow anything from own sec group (Any was not possible)

  rule {
    ip_protocol = "tcp"
    from_port   = "1"
    to_port     = "65535"
    self        = true
  }

  rule {
    ip_protocol = "udp"
    from_port   = "1"
    to_port     = "65535"
    self        = true
  }

  rule {
    ip_protocol = "icmp"
    from_port   = "-1"
    to_port     = "-1"
    self        = true
  }

  rule {
    ip_protocol = "tcp"
    from_port   = "22"
    to_port     = "22"
    cidr        = "0.0.0.0/0"
  }

  rule {
    ip_protocol = "tcp"
    from_port   = "25555"
    to_port     = "25555"
    cidr        = "0.0.0.0/0"
  }

  rule {
    ip_protocol = "tcp"
    from_port   = "6868"
    to_port     = "6868"
    cidr        = "${var.concourse_external_network_cidr}"
  }

  rule {
    ip_protocol = "udp"
    from_port   = "53"
    to_port     = "53"
    cidr        = "${var.concourse_external_network_cidr}"
  }

  rule {
    ip_protocol = "tcp"
    from_port   = "53"
    to_port     = "53"
    cidr        = "${var.concourse_external_network_cidr}"
  }

  rule {
    ip_protocol = "tcp"
    from_port   = "1"
    to_port     = "65535"
    cidr        = "${var.ext_net_cidr}"
  }

  rule {
    ip_protocol = "udp"
    from_port   = "1"
    to_port     = "65535"
    cidr        = "${var.ext_net_cidr}"
  }
}
