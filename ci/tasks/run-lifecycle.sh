#!/usr/bin/env bash

set -e
set -o pipefail

source bosh-cpi-src-in/ci/tasks/utils.sh

: ${BOSH_OPENSTACK_DOMAIN:?}
: ${BOSH_OPENSTACK_AUTH_URL_V3:?}
: ${BOSH_OPENSTACK_USERNAME_V3:?}
: ${BOSH_OPENSTACK_API_KEY_V3:?}
: ${BOSH_OPENSTACK_PROJECT:?}
: ${BOSH_CLI_SILENCE_SLOW_LOAD_WARNING:?}
: ${BOSH_OPENSTACK_CONNECT_TIMEOUT:?}
: ${BOSH_OPENSTACK_READ_TIMEOUT:?}
: ${BOSH_OPENSTACK_WRITE_TIMEOUT:?}
: ${BOSH_OPENSTACK_FLAVOR_WITH_NO_ROOT_DISK:?}
: ${BOSH_OPENSTACK_AUTH_URL_V2:-""}
: ${BOSH_OPENSTACK_USERNAME_V2:-""}
: ${BOSH_OPENSTACK_API_KEY_V2:-""}
: ${BOSH_OPENSTACK_TENANT:-""}
: ${BOSH_OPENSTACK_CA_CERT:-""}
: ${BOSH_OPENSTACK_VOLUME_TYPE:-""}

optional_value BOSH_OPENSTACK_AVAILABILITY_ZONE

metadata=terraform-lifecycle/metadata

export BOSH_OPENSTACK_MANUAL_IP=$(cat ${metadata} | jq --raw-output ".manual_ip")
export BOSH_OPENSTACK_NO_DHCP_MANUAL_IP_1=$(cat ${metadata} | jq --raw-output ".no_dhcp_manual_ip_1")
export BOSH_OPENSTACK_NO_DHCP_MANUAL_IP_2=$(cat ${metadata} | jq --raw-output ".no_dhcp_manual_ip_2")
export BOSH_OPENSTACK_NET_ID=$(cat ${metadata} | jq --raw-output ".net_id")
export BOSH_OPENSTACK_NET_ID_NO_DHCP_1=$(cat ${metadata} | jq --raw-output ".net_id_no_dhcp_1")
export BOSH_OPENSTACK_NET_ID_NO_DHCP_2=$(cat ${metadata} | jq --raw-output ".net_id_no_dhcp_2")
export BOSH_OPENSTACK_DEFAULT_KEY_NAME=$(cat ${metadata} | jq --raw-output ".default_key_name")
export BOSH_OPENSTACK_FLOATING_IP=$(cat ${metadata} | jq --raw-output ".floating_ip")
pool_name=$(cat ${metadata} | jq --raw-output ".loadbalancer_pool_name")
if [ "${pool_name}" != "null" ]; then
  export BOSH_OPENSTACK_LBAAS_POOL_NAME=${pool_name}
fi

mkdir "${PWD}/openstack-lifecycle-stemcell/stemcell"
tar -C "${PWD}/openstack-lifecycle-stemcell/stemcell" -xzf "${PWD}/openstack-lifecycle-stemcell/stemcell.tgz"
export BOSH_OPENSTACK_STEMCELL_PATH="${PWD}/openstack-lifecycle-stemcell/stemcell"

cd bosh-cpi-src-in/src/bosh_openstack_cpi

bundle install

if [ -n "${BOSH_OPENSTACK_AUTH_URL_V2}" ]; then
  bundle exec rspec -f d spec/integration 2>&1 | tee ../../../output/lifecycle.log
else
  echo "Excluding Keystone V2 tests."
  bundle exec rspec -f d spec/integration --exclude-pattern spec/integration/lifecycle_v2_spec.rb 2>&1 | tee ../../../output/lifecycle.log
fi
