#!/usr/bin/env bash

set -e

source /etc/profile.d/chruby.sh
chruby 2.1.2

initver=$(cat teardown-director/bosh-init/version)
initexe="${PWD}/teardown-director/bosh-init/bosh-init-${initver}-linux-amd64"
chmod +x ${initexe}

echo "using bosh-init CLI version..."
$initexe version

director_manifest_filepath=${PWD}/director-manifest/${director_manifest_filename}
echo "deleting existing BOSH Director VM..."
$initexe delete ${director_manifest_filepath}
