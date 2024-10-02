#!/usr/bin/env bash

set -e
set -x

semver=$(cat version-semver/number)
cpi_release_name="bosh-openstack-cpi"

echo "using bosh CLI version..."
bosh-go --version

echo "building CPI release..."
cd bosh-openstack-cpi-release

bosh-go -n create-release \
  --name "${cpi_release_name}" \
  --version "${semver}" \
  --tarball "../candidate/${cpi_release_name}-${semver}.tgz"
