#!/usr/bin/env bash
set -eu -o pipefail

pushd bosh-openstack-cpi-release/src/bosh_openstack_cpi

  bundle install

  bundle exec rake rubocop

  bundle exec rake spec:unit

popd
