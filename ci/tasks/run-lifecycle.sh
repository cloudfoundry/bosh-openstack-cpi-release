#!/usr/bin/env bash

set -e
set -o pipefail

: ${BOSH_OPENSTACK_DOMAIN:?}
: ${BOSH_OPENSTACK_AUTH_URL_V3:?}
: ${BOSH_OPENSTACK_USERNAME_V3:?}
: ${BOSH_OPENSTACK_API_KEY_V3:?}
: ${BOSH_OPENSTACK_PROJECT:?}
: ${BOSH_OPENSTACK_TENANT:?}
: ${BOSH_OPENSTACK_MANUAL_IP:?}
: ${BOSH_OPENSTACK_NO_DHCP_MANUAL_IP_1:?}
: ${BOSH_OPENSTACK_NO_DHCP_MANUAL_IP_2:?}
: ${BOSH_OPENSTACK_NET_ID:?}
: ${BOSH_OPENSTACK_NET_ID_NO_DHCP_1:?}
: ${BOSH_OPENSTACK_NET_ID_NO_DHCP_2:?}
: ${BOSH_OPENSTACK_DEFAULT_KEY_NAME:?}
: ${BOSH_CLI_SILENCE_SLOW_LOAD_WARNING:?}
: ${BOSH_OPENSTACK_CONNECT_TIMEOUT:?}
: ${BOSH_OPENSTACK_READ_TIMEOUT:?}
: ${BOSH_OPENSTACK_WRITE_TIMEOUT:?}
: ${BOSH_OPENSTACK_FLAVOR_WITH_NO_ROOT_DISK:?}
: ${BOSH_OPENSTACK_AUTH_URL_V2:-""}
: ${BOSH_OPENSTACK_USERNAME_V2:-""}
: ${BOSH_OPENSTACK_API_KEY_V2:-""}
: ${BOSH_OPENSTACK_CA_CERT:-""}
: ${BOSH_OPENSTACK_VOLUME_TYPE:-""}

source /etc/profile.d/chruby-with-ruby-2.1.2.sh

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
