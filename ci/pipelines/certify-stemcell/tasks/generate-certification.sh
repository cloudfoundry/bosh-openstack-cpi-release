#!/usr/bin/env bash

set -e

source bosh-cpi-src-in/ci/tasks/utils.sh

ensure_not_replace_value bosh_release_name
ensure_not_replace_value cpi_release_name
ensure_not_replace_value stemcell_name

bosh_release_version=$(cat bosh-release/version)
cpi_release_version=$(cat bosh-cpi-release/version)
stemcell_version=$(cat stemcell/version)

certify-artifacts --release $bosh_release_name/$bosh_release_version \
                  --release $cpi_release_name/$cpi_release_version \
                  --stemcell $stemcell_name/$stemcell_version \
                 > certification-receipt/receipt.json

cat certification-receipt/receipt.json
