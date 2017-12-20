#!/usr/bin/env bash
set -e

echo "running unit tests"
cd pull-request/src/bosh_openstack_cpi
BUNDLE_WITHOUT="development:test" BUNDLE_CACHE_PATH="vendor/package" bundle install --local
bundle config --delete without
bundle install
bundle exec rspec spec/unit/*