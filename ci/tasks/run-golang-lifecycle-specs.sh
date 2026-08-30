#!/usr/bin/env bash

set -euo pipefail

source bosh-openstack-cpi-release/ci/tasks/utils.sh

: "${BOSH_OPENSTACK_DOMAIN:?}"
: "${BOSH_OPENSTACK_AUTH_URL_V3:?}"
: "${BOSH_OPENSTACK_USERNAME_V3:?}"
: "${BOSH_OPENSTACK_API_KEY_V3:?}"
: "${BOSH_OPENSTACK_PROJECT:?}"
: "${BOSH_OPENSTACK_FLAVOR_WITH_NO_ROOT_DISK:?}"
: "${BOSH_OPENSTACK_VOLUME_TYPE:?}"

optional_value BOSH_OPENSTACK_AVAILABILITY_ZONE

# Infrastructure identifiers come from the lifecycle terraform output.
metadata=terraform-cpi/metadata

BOSH_OPENSTACK_MANUAL_IP=$(jq --raw-output ".manual_ip" "${metadata}")
BOSH_OPENSTACK_ALLOWED_ADDRESS_PAIRS=$(jq --raw-output ".allowed_address_pairs" "${metadata}")
BOSH_OPENSTACK_NO_DHCP_MANUAL_IP_1=$(jq --raw-output ".no_dhcp_manual_ip_1" "${metadata}")
BOSH_OPENSTACK_NO_DHCP_MANUAL_IP_2=$(jq --raw-output ".no_dhcp_manual_ip_2" "${metadata}")
BOSH_OPENSTACK_NET_ID=$(jq --raw-output ".net_id" "${metadata}")
BOSH_OPENSTACK_NET_ID_NO_DHCP_1=$(jq --raw-output ".net_id_no_dhcp_1" "${metadata}")
BOSH_OPENSTACK_NET_ID_NO_DHCP_2=$(jq --raw-output ".net_id_no_dhcp_2" "${metadata}")
BOSH_OPENSTACK_DEFAULT_KEY_NAME=$(jq --raw-output ".default_key_name" "${metadata}")
BOSH_OPENSTACK_FLOATING_IP=$(jq --raw-output ".floating_ip" "${metadata}")
BOSH_OPENSTACK_SECURITY_GROUP_NAME=$(jq --raw-output ".security_group_name" "${metadata}")
BOSH_OPENSTACK_SECURITY_GROUP_ID=$(jq --raw-output ".security_group_id" "${metadata}")
export BOSH_OPENSTACK_MANUAL_IP BOSH_OPENSTACK_ALLOWED_ADDRESS_PAIRS \
  BOSH_OPENSTACK_NO_DHCP_MANUAL_IP_1 BOSH_OPENSTACK_NO_DHCP_MANUAL_IP_2 \
  BOSH_OPENSTACK_NET_ID BOSH_OPENSTACK_NET_ID_NO_DHCP_1 BOSH_OPENSTACK_NET_ID_NO_DHCP_2 \
  BOSH_OPENSTACK_DEFAULT_KEY_NAME BOSH_OPENSTACK_FLOATING_IP \
  BOSH_OPENSTACK_SECURITY_GROUP_NAME BOSH_OPENSTACK_SECURITY_GROUP_ID

# Extract the stemcell; the Go harness reads <dir>/stemcell.MF and <dir>/image.
mkdir -p "${PWD}/openstack-lifecycle-stemcell/stemcell"
tar -C "${PWD}/openstack-lifecycle-stemcell/stemcell" -xzf "${PWD}/openstack-lifecycle-stemcell/stemcell.tgz"
export BOSH_OPENSTACK_STEMCELL_PATH="${PWD}/openstack-lifecycle-stemcell/stemcell"

cd bosh-openstack-cpi-release/src/openstack_cpi_golang
go run github.com/onsi/ginkgo/v2/ginkgo --tags lifecycle -r -v lifecycle
