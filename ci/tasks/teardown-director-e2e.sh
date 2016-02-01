#!/usr/bin/env bash

set -e

source bosh-cpi-release/ci/tasks/utils.sh

ensure_not_replace_value bosh_director_ip
ensure_not_replace_value director_state_file
ensure_not_replace_value director_manifest_file

source /etc/profile.d/chruby.sh
chruby 2.1.2

echo "using bosh CLI version..."
bosh version

echo "targeting bosh director at ${bosh_director_ip}"
bosh -n target ${bosh_director_ip}
bosh login admin admin

echo "cleanup director (especially orphan disks)"
bosh -n cleanup --all



export BOSH_INIT_LOG_LEVEL=DEBUG

working_dir=${PWD}/director-manifest-file


cp ./director-state-file/${director_state_file} ${working_dir}/
cp ./published-bosh-cpi-release/release.tgz ${working_dir}/bosh-openstack-cpi.tgz
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
