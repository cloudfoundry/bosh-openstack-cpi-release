#!/usr/bin/env bash

# Provisions a self-contained DevStack OpenStack on a fresh Ubuntu 24.04 (Noble) GCP VM.
# Runs as a sudo-capable non-root user. Invoked by the create-devstack CI task.

set -euo pipefail

### ----- Tunables (can be overridden via environment variables) ---------------------------------
DEVSTACK_BRANCH="${DEVSTACK_BRANCH:-stable/2025.1}"          # Epoxy
STACK_USER="${STACK_USER:-stack}"
STACK_DIR="${STACK_DIR:-/opt/stack}"

# OpenStack identity defaults — override via environment or VM metadata.
OS_PROJECT="${OS_PROJECT:-bosh}"
OS_USERNAME="${OS_USERNAME:-bosh}"
OS_PASSWORD="${OS_PASSWORD:-bosh-ci-password}"
OS_DOMAIN="${OS_DOMAIN:-Default}"
OS_REGION="${OS_REGION:-RegionOne}"

# HOST_IP is pinned so auth_url is stable across per-run VMs. Should be set to the VM's static
# internal IP. Falls back to the primary NIC address.
HOST_IP="${HOST_IP:-$(ip -4 route get 1.1.1.1 | awk '{print $7; exit}')}"

# DevStack external ("public") network. DevStack always regenerates the neutron network UUID, so
# downstream terraform resolves it by name. Only name and CIDR are pinned here.
EXT_NET_NAME="${EXT_NET_NAME:-public}"
FLOATING_RANGE="${FLOATING_RANGE:-172.24.4.0/24}"
PUBLIC_NETWORK_GATEWAY="${PUBLIC_NETWORK_GATEWAY:-172.24.4.1}"

# CIDR of the Concourse workers that must reach DevStack floating IPs off-box (bosh-concourse subnet).
WORKER_SOURCE_CIDR="${WORKER_SOURCE_CIDR:-10.0.0.0/24}"

METADATA_OUT="${METADATA_OUT:-/opt/openstack-metadata.json}"
### ---------------------------------------------------------------------------------------------

log() { echo "[install-devstack] $*"; }

metadata_attr() {
  curl -s -H "Metadata-Flavor: Google" \
    "http://metadata.google.internal/computeMetadata/v1/instance/attributes/$1" 2>/dev/null || true
}

# The OpenStack user/password are supplied via VM metadata (from CredHub, out of the repo). Falls back
# to the defaults above for manual runs. Called after install_prereqs so curl is present.
load_credentials() {
  local u p
  u="$(metadata_attr os-username)"; [ -n "$u" ] && OS_USERNAME="$u"
  p="$(metadata_attr os-password)"; [ -n "$p" ] && OS_PASSWORD="$p"
}

install_prereqs() {
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update -y
  sudo apt-get install -y git python3 python3-venv python3-pip jq curl net-tools qemu-kvm
  if ! id "${STACK_USER}" &>/dev/null; then
    sudo useradd -s /bin/bash -d "${STACK_DIR}" -m "${STACK_USER}"
    echo "${STACK_USER} ALL=(ALL) NOPASSWD: ALL" | sudo tee "/etc/sudoers.d/${STACK_USER}" >/dev/null
  fi
  sudo chmod 0755 "${STACK_DIR}"
}

clone_devstack() {
  if [[ ! -d "${STACK_DIR}/devstack" ]]; then
    sudo -u "${STACK_USER}" git clone https://opendev.org/openstack/devstack "${STACK_DIR}/devstack" \
      --branch "${DEVSTACK_BRANCH}" --depth 1
  fi
}

write_local_conf() {
  # DevStack serves plain HTTP (no tls-proxy): this is a disposable test cloud reached only over the
  # bosh-concourse VPC, so no CA to juggle per run.
  sudo -u "${STACK_USER}" tee "${STACK_DIR}/devstack/local.conf" >/dev/null <<EOF
[[local|localrc]]
HOST_IP=${HOST_IP}
SERVICE_HOST=${HOST_IP}

ADMIN_PASSWORD=${OS_PASSWORD}
DATABASE_PASSWORD=\$ADMIN_PASSWORD
RABBIT_PASSWORD=\$ADMIN_PASSWORD
SERVICE_PASSWORD=\$ADMIN_PASSWORD

# Public/external network — name pinned, CIDR pinned; UUID is discovered post-install.
FLOATING_RANGE=${FLOATING_RANGE}
PUBLIC_NETWORK_GATEWAY=${PUBLIC_NETWORK_GATEWAY}
PUBLIC_INTERFACE=

# Core services only; keep it lean for the 4 vCPU box.
disable_service horizon
disable_service tempest

LOGFILE=${STACK_DIR}/devstack/stack.sh.log
LOGDAYS=1
EOF
}

run_stack() {
  log "Running stack.sh (this is the long pole, ~20-40 min from scratch)..."
  sudo -u "${STACK_USER}" bash -c "cd ${STACK_DIR}/devstack && ./stack.sh"
}

os_admin() {
  # openstack CLI as admin against the freshly-installed cloud.
  sudo -u "${STACK_USER}" bash -c \
    "source ${STACK_DIR}/devstack/openrc admin admin >/dev/null 2>&1 && openstack $*"
}

configure_offbox_floating_access() {
  # Let Concourse workers (off the VM) reach DevStack floating IPs. Traffic is routed here by a GCP VPC
  # route (dest=floating_range, next-hop=this VM) + can_ip_forward. OVN's external network drops
  # off-subnet sources, so hairpin-SNAT the worker source to the br-ex gateway IP.
  sudo sysctl -w net.ipv4.ip_forward=1
  sudo iptables -t nat -C POSTROUTING -s "${WORKER_SOURCE_CIDR}" -d "${FLOATING_RANGE}" -j SNAT --to-source "${PUBLIC_NETWORK_GATEWAY}" 2>/dev/null || \
    sudo iptables -t nat -A POSTROUTING -s "${WORKER_SOURCE_CIDR}" -d "${FLOATING_RANGE}" -j SNAT --to-source "${PUBLIC_NETWORK_GATEWAY}"
}

register_volumev3_alias() {
  # Cinder registers as service type `block-storage`; the fog-openstack gem the CPI/tests use
  # expects a `volumev3` service. Register an alias endpoint pointing at the same Cinder URL.
  local cinder_url
  cinder_url="$(os_admin endpoint list --service block-storage --interface public -f value -c URL | head -1)"
  if [[ -n "${cinder_url}" ]]; then
    if ! os_admin service list -f value -c Type | grep -qx volumev3; then
      os_admin service create --name cinderv3-alias volumev3
      os_admin endpoint create volumev3 public "${cinder_url}" --region "${OS_REGION}"
      os_admin endpoint create volumev3 internal "${cinder_url}" --region "${OS_REGION}"
      os_admin endpoint create volumev3 admin "${cinder_url}" --region "${OS_REGION}"
    fi
  fi
}

create_project_and_user() {
  os_admin project show "${OS_PROJECT}" >/dev/null 2>&1 || os_admin project create --domain "${OS_DOMAIN}" "${OS_PROJECT}"
  os_admin user show "${OS_USERNAME}" >/dev/null 2>&1 || \
    os_admin user create --domain "${OS_DOMAIN}" --password "${OS_PASSWORD}" "${OS_USERNAME}"
  os_admin role add --project "${OS_PROJECT}" --user "${OS_USERNAME}" member || true
  os_admin role add --project "${OS_PROJECT}" --user "${OS_USERNAME}" admin || true
}

create_flavors() {
  # Test flavors required by the lifecycle and BATS suites.
  os_admin flavor show m1.small >/dev/null 2>&1 || os_admin flavor create --ram 2048 --disk 20 --vcpus 1 m1.small
  os_admin flavor show no-root-disk >/dev/null 2>&1 || \
    os_admin flavor create --ram 1024 --disk 0 --vcpus 1 no-root-disk
  os_admin flavor show with-ephemeral-disk >/dev/null 2>&1 || \
    os_admin flavor create --ram 1024 --disk 5 --ephemeral 5 --vcpus 1 with-ephemeral-disk
  os_admin flavor show without-ephemeral-disk >/dev/null 2>&1 || \
    os_admin flavor create --ram 1024 --disk 5 --ephemeral 0 --vcpus 1 without-ephemeral-disk
}

bump_quotas() {
  os_admin quota set --instances 20 --cores 20 --ram 40960 \
    --volumes 20 --gigabytes 200 \
    --networks 20 --subnets 40 --ports 100 --routers 20 --floating-ips 20 --secgroups 40 \
    "${OS_PROJECT}"
}

upload_jammy_stemcell() {
  # The lifecycle suite uploads its own stemcell via the CPI; BATS needs the Jammy image present in
  # Glance for the director/deployment stemcell. Skip if STEMCELL_IMAGE_PATH not provided.
  if [[ -n "${STEMCELL_IMAGE_PATH:-}" && -f "${STEMCELL_IMAGE_PATH}" ]]; then
    os_admin image show bosh-openstack-kvm-ubuntu-jammy-go_agent >/dev/null 2>&1 || \
      os_admin image create --disk-format qcow2 --container-format bare \
        --file "${STEMCELL_IMAGE_PATH}" bosh-openstack-kvm-ubuntu-jammy-go_agent
  else
    log "STEMCELL_IMAGE_PATH not set; skipping Glance stemcell upload (lifecycle uploads its own)."
  fi
}

emit_metadata() {
  # Values the pipeline may want for debugging; ext net is resolved by NAME downstream (UUID is per-run).
  local ext_net_id
  ext_net_id="$(os_admin network show "${EXT_NET_NAME}" -f value -c id || true)"
  cat <<EOF | sudo tee "${METADATA_OUT}" >/dev/null
{
  "auth_url": "http://${HOST_IP}/identity",
  "openstack_domain": "${OS_DOMAIN}",
  "openstack_project": "${OS_PROJECT}",
  "openstack_username": "${OS_USERNAME}",
  "region": "${OS_REGION}",
  "ext_net_name": "${EXT_NET_NAME}",
  "ext_net_id": "${ext_net_id}",
  "ext_net_cidr": "${FLOATING_RANGE}"
}
EOF
  log "Wrote ${METADATA_OUT}:"; sudo cat "${METADATA_OUT}"
}

main() {
  install_prereqs
  load_credentials
  clone_devstack
  write_local_conf
  run_stack
  configure_offbox_floating_access
  register_volumev3_alias
  create_project_and_user
  create_flavors
  bump_quotas
  upload_jammy_stemcell
  emit_metadata
  log "DevStack ready."
}

main "$@"
