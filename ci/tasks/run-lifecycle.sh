#!/usr/bin/env bash

set -e
set -o pipefail

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

source /etc/profile.d/chruby-with-ruby-2.1.2.sh

metadata=terraform-lifecycle/metadata

export BOSH_OPENSTACK_MANUAL_IP=$(cat ${metadata} | jq --raw-output ".lifecycle_manual_ip")
export BOSH_OPENSTACK_NO_DHCP_MANUAL_IP_1=$(cat ${metadata} | jq --raw-output ".lifecycle_no_dhcp_manual_ip_1")
export BOSH_OPENSTACK_NO_DHCP_MANUAL_IP_2=$(cat ${metadata} | jq --raw-output ".lifecycle_no_dhcp_manual_ip_2")
export BOSH_OPENSTACK_NET_ID=$(cat ${metadata} | jq --raw-output ".lifecycle_openstack_net_id")
export BOSH_OPENSTACK_NET_ID_NO_DHCP_1=$(cat ${metadata} | jq --raw-output ".lifecycle_net_id_no_dhcp_1")
export BOSH_OPENSTACK_NET_ID_NO_DHCP_2=$(cat ${metadata} | jq --raw-output ".lifecycle_net_id_no_dhcp_2")
export BOSH_OPENSTACK_DEFAULT_KEY_NAME=$(cat ${metadata} | jq --raw-output ".lifecycle_key_name")

mkdir "${PWD}/openstack-lifecycle-stemcell/stemcell"
tar -C "${PWD}/openstack-lifecycle-stemcell/stemcell" -xzf "${PWD}/openstack-lifecycle-stemcell/stemcell.tgz"
export BOSH_OPENSTACK_STEMCELL_PATH="${PWD}/openstack-lifecycle-stemcell/stemcell"

cd bosh-cpi-src-in/src/bosh_openstack_cpi

bundle install

if [ -n "${BOSH_OPENSTACK_AUTH_URL_V2}" ]; then
  bundle exec rspec spec/integration 2>&1 | tee ../../../output/lifecycle.log
else
  echo "Excluding Keystone V2 tests."
  bundle exec rspec spec/integration --exclude-pattern spec/integration/lifecycle_v2_spec.rb 2>&1 | tee ../../../output/lifecycle.log
fi
