#!/usr/bin/env bash

set -e -x

ensure_not_replace_value() {
  local name=$1
  local value=$(eval echo '$'$name)
  if [ "$value" == 'replace-me' ]; then
    echo "environment variable $name must be set"
    exit 1
  fi
}

ensure_not_replace_value base_os
ensure_not_replace_value network_type_to_test

cpi_release_name=bosh-openstack-cpi

save_location=deploy/bosh-concourse-ci/pipelines/${cpi_release_name}
state_filename=${base_os}-${network_type_to_test}-director-manifest-state.json

echo "checking in BOSH deployment state"
cp deploy/tmp/${state_filename} ${save_location}/${state_filename}
cd ${save_location}
git add ${state_filename}
git config --global user.email "cf-bosh-eng+bosh-ci@pivotal.io"
git config --global user.name "bosh-ci"
git commit -m ":airplane: Concourse auto-updating deployment state for bats pipeline, on $base_os/$network_type_to_test"