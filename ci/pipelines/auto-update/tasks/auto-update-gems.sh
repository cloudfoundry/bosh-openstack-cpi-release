#!/usr/bin/env bash

set -e
set -x

cd bosh-cpi-src-in
pushd src/bosh_openstack_cpi
  echo "looking for new gem versions"
  rm Gemfile.lock
  ./vendor_gems
  changes=$(git diff Gemfile.lock | wc -l)
  echo ${changes}

  echo "running unit tests"
  bundle install
  bundle exec rspec spec/unit/*
popd

echo "creating new pull request"
# git add .
# git commit
