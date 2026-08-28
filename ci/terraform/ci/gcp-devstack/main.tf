# GCP-side infrastructure for the OpenStack CPI test environment: an N2 VM that runs DevStack,
# attached to the community Concourse VPC (bosh-concourse) so the Concourse workers can reach it.
#
# Two reachability paths for the workers:
#   1. DevStack API  -> the VM's internal IP (allowed by google_compute_firewall.devstack).
#   2. Floating IPs  -> routed to the VM (google_compute_route.floating) + can_ip_forward, plus a
#      SNAT hairpin rule applied by install-devstack.sh so OVN accepts the off-subnet worker source.
# The VM has no external IP; bosh-concourse Cloud NAT provides egress for the DevStack install.

provider "google" {
  project     = var.project
  region      = var.region
  credentials = var.gcp_credentials_json != "" ? var.gcp_credentials_json : null
}

variable "gcp_credentials_json" {
  description = "Service-account JSON key. Leave empty to use GOOGLE_CREDENTIALS / ADC."
  type        = string
  default     = ""
  sensitive   = true
}

variable "project" {
  default = "cloud-foundry-310819"
}

variable "region" {
  default = "europe-west2"
}

variable "zone" {
  default = "europe-west2-a" # same zone as the Concourse workers
}

variable "network" {
  description = "Existing VPC the Concourse workers live in."
  default     = "bosh-concourse"
}

variable "subnet_name" {
  default = "devstack-openstack-cpi"
}

variable "subnet_cidr" {
  description = "Dedicated subnet; must not overlap 10.0.0.0/24 or the 10.100.x integration ranges."
  default     = "10.100.30.0/24"
}

variable "vm_name" {
  default = "devstack-openstack-cpi"
}

variable "machine_type" {
  description = "Must be a nested-virt-capable Intel type (e.g. N2). NOT E2 and NOT N2D (no vmx exposed)."
  default     = "n2-standard-4"
}

variable "boot_disk_size" {
  default = 120
}

variable "boot_disk_type" {
  default = "pd-balanced"
}

variable "image" {
  default = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2404-lts-amd64"
}

variable "private_ip" {
  description = "Pinned internal IP so the OpenStack auth_url stays stable across per-run VMs."
  type        = string
  default     = "10.100.30.2"
}

variable "floating_range" {
  description = "DevStack external/floating network CIDR; routed to the VM for worker reachability."
  default     = "172.24.4.0/24"
}

variable "worker_source_ranges" {
  description = "CIDRs allowed to reach the VM + floating range (the Concourse worker subnet)."
  type        = list(string)
  default     = ["10.0.0.0/24"]
}

variable "network_tag" {
  default = "devstack-openstack-cpi"
}

variable "os_username" {
  description = "OpenStack user the pipeline authenticates as; created inside DevStack by install-devstack.sh."
  type        = string
  default     = "bosh"
}

variable "os_password" {
  description = "Password for os_username. Passed to the VM as metadata, never committed to the repo."
  type        = string
  sensitive   = true
}

resource "google_compute_subnetwork" "devstack" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = var.network
}

resource "google_compute_instance" "devstack" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = [var.network_tag]

  boot_disk {
    initialize_params {
      image = var.image
      size  = var.boot_disk_size
      type  = var.boot_disk_type
    }
  }

  # Nested KVM for BOSH stemcells. Requires an Intel (N2) type; the flag adds the vmx license.
  advanced_machine_features {
    enable_nested_virtualization = true
  }

  can_ip_forward = true # required to forward floating-range traffic to br-ex

  network_interface {
    subnetwork = google_compute_subnetwork.devstack.self_link
    network_ip = var.private_ip != "" ? var.private_ip : null
    # No access_config: internal-only. Egress via bosh-concourse Cloud NAT.
  }

  # DevStack is installed on boot; install-devstack.sh also applies the SNAT hairpin rule.
  # os-username/os-password are read by the script from the metadata server (kept out of the repo).
  metadata = {
    startup-script = file("${path.module}/install-devstack.sh")
    os-username    = var.os_username
    os-password    = var.os_password
  }
}

# Route floating IPs to the DevStack VM (longest-prefix match beats the default route).
resource "google_compute_route" "floating" {
  name              = "${var.vm_name}-floating"
  network           = var.network
  dest_range        = var.floating_range
  next_hop_instance = google_compute_instance.devstack.self_link
  priority          = 900
}

# Allow the workers to reach the VM (API) and, via the route, the floating range. Target-tagged so it
# cannot affect anything else in the shared VPC.
resource "google_compute_firewall" "devstack" {
  name          = "${var.vm_name}-access"
  network       = var.network
  direction     = "INGRESS"
  source_ranges = var.worker_source_ranges
  target_tags   = [var.network_tag]

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
}

output "vm_internal_ip" {
  value = google_compute_instance.devstack.network_interface[0].network_ip
}

output "auth_url" {
  value = "http://${google_compute_instance.devstack.network_interface[0].network_ip}/identity"
}

output "floating_range" {
  value = var.floating_range
}

output "subnet" {
  value = google_compute_subnetwork.devstack.self_link
}
