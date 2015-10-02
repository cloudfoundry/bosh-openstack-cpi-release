#!/usr/bin/env bash

set -e

source bosh-cpi-release/ci/tasks/utils.sh

ensure_not_replace_value base_os
ensure_not_replace_value network_type

source /etc/profile.d/chruby.sh
chruby 2.1.2


semver=`cat version-semver/number`
cpi_release_name="bosh-openstack-cpi"
working_dir=${PWD}/director-manifest
director_manifest_filename=${working_dir}/${base_os}-${network_type}-director-manifest.yml

cp ./director-state-file/${base_os}-${network_type}-director-manifest-state.json ${working_dir}/
cp ./bosh-cpi-dev-artifacts/${cpi_release_name}-${semver}.tgz ${working_dir}/${cpi_release_name}.tgz
cp ./bosh-release/release.tgz ${working_dir}/bosh-release.tgz
cp ./stemcell/stemcell.tgz ${working_dir}/stemcell.tgz

initver=$(cat bosh-init/version)
initexe="${PWD}/bosh-init/bosh-init-${initver}-linux-amd64"
chmod +x ${initexe}

echo "using bosh-init CLI version..."
$initexe version

echo "deleting existing BOSH Director VM..."
$initexe delete ${director_manifest_filename}
