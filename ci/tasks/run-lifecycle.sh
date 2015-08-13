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
ensure_not_replace_value BOSH_OPENSTACK_STEMCELL_ID

source /etc/profile.d/chruby-with-ruby-2.1.2.sh

cd bosh-src/bosh_openstack_cpi

bundle install
bundle exec rake spec:lifecycle
