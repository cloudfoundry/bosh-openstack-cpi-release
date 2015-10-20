#!/usr/bin/env bash

set -e

source bosh-cpi-release/ci/tasks/utils.sh

ensure_not_replace_value director_state_file
ensure_not_replace_value director_manifest_file

source /etc/profile.d/chruby.sh
chruby 2.1.2


semver=`cat version-semver/number`
cpi_release_name="bosh-openstack-cpi"
working_dir=${PWD}/director-manifest


cp ./director-state-file/${director_state_file} ${working_dir}/
cp ./bosh-cpi-dev-artifacts/${cpi_release_name}-${semver}.tgz ${working_dir}/${cpi_release_name}.tgz
cp ./bosh-release/release.tgz ${working_dir}/bosh-release.tgz
cp ./stemcell/stemcell.tgz ${working_dir}/stemcell.tgz

initver=$(cat bosh-init/version)
initexe="${PWD}/bosh-init/bosh-init-${initver}-linux-amd64"
chmod +x ${initexe}

echo "using bosh-init CLI version..."
$initexe version

echo "deleting existing BOSH Director VM..."
$initexe delete ${working_dir}/${director_manifest_file}

echo "{}" >> ${working_dir}/${director_state_file}
