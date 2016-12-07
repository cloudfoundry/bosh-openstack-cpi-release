#!/usr/bin/env bash

set -e

source bosh-cpi-src-in/ci/tasks/utils.sh

ensure_not_replace_value bosh_admin_password

metadata=terraform/metadata

export_terraform_variable "director_public_ip"

export BOSH_INIT_LOG_LEVEL=DEBUG

source /etc/profile.d/chruby.sh
chruby 2.1.2

echo "using bosh CLI version..."
bosh version

echo "targeting bosh director at ${director_public_ip}"
bosh -n target ${director_public_ip}
bosh login admin ${bosh_admin_password}

echo "cleanup director (especially orphan disks)"
bosh -n cleanup --all

echo "Copying inputs..."
cp ./deployment/e2e-director-manifest* .
cp ./bosh-cpi-release/*.tgz bosh-openstack-cpi.tgz
cp ./bosh-release/release.tgz bosh-release.tgz
cp ./stemcell/stemcell.tgz stemcell.tgz

initver=$(cat bosh-init/version)
initexe="${PWD}/bosh-init/bosh-init-${initver}-linux-amd64"
chmod +x ${initexe}

echo "using bosh-init CLI version..."
$initexe version

echo "deleting existing BOSH Director VM..."
$initexe delete e2e-director-manifest.yml
