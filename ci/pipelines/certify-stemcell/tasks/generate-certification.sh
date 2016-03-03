#!/usr/bin/env bash

set -e

source bosh-cpi-src-in/ci/tasks/utils.sh

ensure_not_replace_value bosh_release_name
ensure_not_replace_value cpi_release_name
ensure_not_replace_value stemcell_name

timestamp=`date -u +"%Y-%m-%dT%H:%M:%SZ"`
bosh_release_version=$(cat bosh-release/version)
cpi_release_version=$(cat bosh-cpi-release/version)
stemcell_version=$(cat stemcell/version)

contents_hash=$(echo ${bosh_release_name}-${bosh_release_version}-${cpi_release_name}-${cpi_release_version}-${stemcell_name}-${stemcell_version} | md5sum | cut -f1 -d ' ')

certify-artifacts --release $bosh_release_name/$bosh_release_version \
                  --release $cpi_release_name/$cpi_release_version \
                  --stemcell $stemcell_name/$stemcell_version \
                 > certification-receipt/${timestamp}-${contents_hash}-receipt.json