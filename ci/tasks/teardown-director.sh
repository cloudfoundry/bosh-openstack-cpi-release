#!/usr/bin/env bash

set -e

source bosh-cpi-src-in/ci/tasks/utils.sh

metadata=terraform-bats/metadata

export_terraform_variable "director_public_ip"

deployment_dir=${PWD}/bosh-director-deployment

cd ${deployment_dir}

export BOSH_ENVIRONMENT=${director_public_ip}
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=$(bosh-go int credentials.yml  --path /admin_password)
export BOSH_CA_CERT="$(bosh-go int credentials.yml --path /director_ssl/ca)"

echo "using bosh CLI version..."
bosh-go --version

echo "cleaning up director... (especially orphan disks)"
bosh-go -n clean-up --all

echo "deleting BOSH..."
bosh-go delete-env \
    --state bosh-state.json \
    --vars-file credentials.yml \
    bosh.yml
