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

cpi_release_name=bosh-openstack-cpi

manifest_dir=bosh-concourse-ci/pipelines/$cpi_release_name

echo "checking in BOSH deployment state"
cd deploy/$manifest_dir
git add $base_os-director-manifest-state.json
git config --global user.email "cf-bosh-eng+bosh-ci@pivotal.io"
git config --global user.name "bosh-ci"
git commit -m ":airplane: Concourse auto-updating deployment state for bats pipeline, on $base_os"
