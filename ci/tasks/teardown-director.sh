#!/usr/bin/env bash

set -e

source bosh-cpi-src-in/ci/tasks/utils.sh

: ${bosh_admin_password:?}

metadata=terraform-bats/metadata

export_terraform_variable "director_public_ip"

echo "using bosh CLI version..."
bosh version

echo "targeting bosh director at ${director_public_ip}"
bosh -n target ${director_public_ip}
bosh login admin ${bosh_admin_password}

echo "cleanup director (especially orphan disks)"
bosh -n cleanup --all



export BOSH_INIT_LOG_LEVEL=DEBUG

semver=`cat version-semver/number`
cpi_release_name="bosh-openstack-cpi"
working_dir=${PWD}/bosh-director-deployment

cp ./bosh-cpi-dev-artifacts/${cpi_release_name}-${semver}.tgz ${working_dir}/${cpi_release_name}.tgz
cp ./bosh-release/release.tgz ${working_dir}/bosh-release.tgz
cp ./stemcell/stemcell.tgz ${working_dir}/stemcell.tgz

initver=$(cat bosh-init/version)
initexe="${PWD}/bosh-init/bosh-init-${initver}-linux-amd64"
chmod +x ${initexe}

echo "using bosh-init CLI version..."
$initexe version

echo "deleting existing BOSH Director VM..."
$initexe delete ${working_dir}/bosh.yml
