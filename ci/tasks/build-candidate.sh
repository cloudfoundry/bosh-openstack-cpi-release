#!/usr/bin/env bash

set -e
set -x

semver=`cat version-semver/number`

cd bosh-cpi-src-in

echo "running unit tests"
pushd src/bosh_openstack_cpi
  BUNDLE_WITHOUT="development:test" BUNDLE_CACHE_PATH="vendor/package" bundle install --local
  bundle config --delete without
  bundle install
  bundle exec rspec spec/unit/*
popd

echo "using bosh CLI version..."
bosh-go --version

cpi_release_name="bosh-openstack-cpi"

echo "building CPI release..."
bosh-go -n create-release --name $cpi_release_name --version $semver --tarball ../candidate/$cpi_release_name-$semver.tgz
