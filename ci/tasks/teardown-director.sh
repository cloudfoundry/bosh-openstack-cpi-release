#!/usr/bin/env bash

set -e

source bosh-cpi-release/ci/tasks/utils.sh

ensure_not_replace_value base_os
ensure_not_replace_value network_type

source /etc/profile.d/chruby.sh
chruby 2.1.2

initver=$(cat bosh-init/version)
initexe="${PWD}/bosh-init/bosh-init-${initver}-linux-amd64"
chmod +x ${initexe}

echo "using bosh-init CLI version..."
$initexe version

working_dir=${PWD}/director-manifest
mv ${PWD}/director-state-file/${base_os}-${network_type}-director-manifest-state.json ${working_dir}/

director_manifest=${working_dir}/${base_os}-${network_type}-director-manifest.yml
echo "deleting existing BOSH Director VM..."
$initexe delete ${director_manifest}
