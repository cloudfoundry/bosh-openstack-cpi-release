#!/usr/bin/env bash

set -e

source bosh-cpi-src-in/ci/tasks/utils.sh

: ${bosh_release_name:?}
: ${cpi_release_name:?}
: ${stemcell_name:?}

timestamp="$(date -u +%Y%m%d%H%M%S)"
bosh_release_version=$(cat bosh-release/version)
cpi_release_version=$(cat bosh-cpi-release/version)
stemcell_version=$(cat stemcell/version)

contents_hash=$(echo ${bosh_release_name}-${bosh_release_version}-${cpi_release_name}-${cpi_release_version}-${stemcell_name}-${stemcell_version} | md5sum | cut -f1 -d ' ')

certify-artifacts --release $bosh_release_name/$bosh_release_version \
                  --release $cpi_release_name/$cpi_release_version \
                  --stemcell $stemcell_name/$stemcell_version \
                 > certification-receipt/${contents_hash}-${timestamp}-receipt.json

cat certification-receipt/${contents_hash}-${timestamp}-receipt.json
