#!/usr/bin/env bash

set -e

ensure_not_replace_value() {
  local name=$1
  local value=$(eval echo '$'$name)
  if [ "$value" == 'replace-me' ]; then
    echo "environment variable $name must be set"
    exit 1
  fi
}

ensure_not_replace_value BOSH_OPENSTACK_AUTH_URL
ensure_not_replace_value BOSH_OPENSTACK_USERNAME
ensure_not_replace_value BOSH_OPENSTACK_API_KEY
ensure_not_replace_value BOSH_OPENSTACK_TENANT
ensure_not_replace_value BOSH_OPENSTACK_MANUAL_IP
ensure_not_replace_value BOSH_OPENSTACK_NET_ID

export BOSH_CLI_SILENCE_SLOW_LOAD_WARNING=true
export BOSH_OPENSTACK_STEMCELL_ID="b3683c70-d0db-4ed0-a3ea-51239efbc08b"
export BOSH_OPENSTACK_VOLUME_TYPE="SSD"

source /etc/profile.d/chruby.sh
chruby 2.1.6

cd bosh-src/bosh_openstack_cpi

bundle install
bundle exec rake spec:lifecycle
