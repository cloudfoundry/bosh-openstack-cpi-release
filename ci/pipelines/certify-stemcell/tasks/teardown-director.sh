#!/usr/bin/env bash

set -e

source bosh-cpi-src-in/ci/tasks/utils.sh

: ${bosh_admin_password:?}

metadata=terraform/metadata

export_terraform_variable "director_public_ip"

deployment_dir="${PWD}/director-deployment"
manifest_filename="e2e-director-manifest"

cd ${deployment_dir}

export BOSH_INIT_LOG_LEVEL=DEBUG
export BOSH_ENVIRONMENT=${director_public_ip}
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=${bosh_admin_password}
export BOSH_CA_CERT=director_ca

echo "using bosh CLI version..."
bosh-go --version

echo "cleaning up director... (especially orphan disks)"
bosh-go -n clean-up --all

echo "deleting BOSH..."
bosh-go delete-env \
    --state ${manifest_filename}-state.json \
    ${manifest_filename}.yml
