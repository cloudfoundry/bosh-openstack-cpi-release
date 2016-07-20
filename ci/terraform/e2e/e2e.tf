provider "openstack" {
  auth_url    = "${var.auth_url}"
  user_name   = "${var.user_name}"
  password    = "${var.password}"
  tenant_name = "${var.tenant_name}"
  domain_name = "${var.domain_name}"
  insecure    = "${var.insecure}"
}

resource "openstack_compute_keypair_v2" "v3_e2e_default_key_name" {
  region     = "${var.region_name}"
  name       = "${var.v3_e2e_default_key_name_prefix}-${var.tenant_name}"
  public_key = "${var.v3_e2e_default_key_public_key}"
}

resource "openstack_networking_network_v2" "v3_e2e_net" {
  region         = "${var.region_name}"
  name           = "v3-e2e"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "v3_e2e_subnet" {
  region           = "${var.region_name}"
  network_id       = "${openstack_networking_network_v2.v3_e2e_net.id}"
  cidr             = "10.0.8.0/24"
  ip_version       = 4
  name             = "v3-e2e-sub"
  allocation_pools = {
    start = "10.0.8.200"
    end   = "10.0.8.254"
  }
  gateway_ip       = "10.0.8.1"
  enable_dhcp      = "true"
  dns_nameservers = ["${compact(split(",",var.dns_nameservers))}"]
}

# router

resource "openstack_networking_router_v2" "e2e_router" {
  region           = "${var.region_name}"
  name             = "e2e-router"
  admin_state_up   = "true"
  external_gateway = "${var.ext_net_id}"
}

resource "openstack_networking_router_interface_v2" "v3_e2e_port" {
  region    = "${var.region_name}"
  router_id = "${openstack_networking_router_v2.e2e_router.id}"
  subnet_id = "${openstack_networking_subnet_v2.v3_e2e_subnet.id}"
}

# no-dhcp network
resource "openstack_networking_network_v2" "v3_e2e_no_dhcp_1_net" {
  region         = "${var.region_name}"
  name           = "v3-e2e-no-dhcp-1"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "v3_e2e_no_dhcp_1_subnet" {
  region           = "${var.region_name}"
  network_id       = "${openstack_networking_network_v2.v3_e2e_no_dhcp_1_net.id}"
  cidr             = "10.0.9.0/24"
  ip_version       = 4
  name             = "v3-e2e-no-dhcp-1-sub"
  allocation_pools = {
    start = "10.0.9.200"
    end   = "10.0.9.254"
  }
  gateway_ip       = "10.0.9.1"
  enable_dhcp      = "false"
  dns_nameservers = ["${compact(split(",",var.dns_nameservers))}"]
}

resource "openstack_networking_router_interface_v2" "v3_e2e_no_dhcp_1_port" {
  region    = "${var.region_name}"
  router_id = "${openstack_networking_router_v2.e2e_router.id}"
  subnet_id = "${openstack_networking_subnet_v2.v3_e2e_no_dhcp_1_subnet.id}"
}

resource "openstack_networking_network_v2" "v3_e2e_no_dhcp_2_net" {
  region         = "${var.region_name}"
  name           = "v3-e2e-no-dhcp-2"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "v3_e2e_no_dhcp_2_subnet" {
  region           = "${var.region_name}"
  network_id       = "${openstack_networking_network_v2.v3_e2e_no_dhcp_2_net.id}"
  cidr             = "10.0.10.0/24"
  ip_version       = 4
  name             = "v3-e2e-no-dhcp-2-sub"
  allocation_pools = {
    start = "10.0.10.200"
    end   = "10.0.10.254"
  }
  gateway_ip       = "10.0.10.1"
  enable_dhcp      = "false"
  dns_nameservers = ["${compact(split(",",var.dns_nameservers))}"]
}

resource "openstack_networking_router_interface_v2" "v3_e2e_no_dhcp_2_port" {
  region    = "${var.region_name}"
  router_id = "${openstack_networking_router_v2.e2e_router.id}"
  subnet_id = "${openstack_networking_subnet_v2.v3_e2e_no_dhcp_2_subnet.id}"
}
# end no-dhcp networks

resource "openstack_compute_floatingip_v2" "v3_e2e_ubuntu_director_floating_ip" {
  region = "${var.region_name}"
  pool   = "${var.ext_net_name}"
}

resource "openstack_compute_floatingip_v2" "v3_e2e_centos_director_floating_ip" {
  region = "${var.region_name}"
  pool   = "${var.ext_net_name}"
}

resource "openstack_compute_floatingip_v2" "v3_e2e_ubuntu_config_drive_floating_ip" {
  region = "${var.region_name}"
  pool   = "${var.ext_net_name}"
}

resource "openstack_compute_floatingip_v2" "v3_e2e_centos_config_drive_floating_ip" {
  region = "${var.region_name}"
  pool   = "${var.ext_net_name}"
}

resource "openstack_compute_floatingip_v2" "v3_ubuntu_upgrade_director_floating_ip" {
  region = "${var.region_name}"
  pool   = "${var.ext_net_name}"
}

resource "openstack_compute_floatingip_v2" "v3_centos_upgrade_director_floating_ip" {
  region = "${var.region_name}"
  pool   = "${var.ext_net_name}"
}

resource "openstack_compute_secgroup_v2" "e2e_secgroup" {
  region      = "${var.region_name}"
  name        = "e2e"
  description = "e2e security group"

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
