#!/usr/bin/env bash

set -e
set -x

cp -r gems-src-in/. gems-src-out
cd gems-src-out/src/bosh_openstack_cpi
git config --global user.email cf-bosh-eng@pivotal.io
git config --global user.name CI
git fetch origin master:refs/remotes/origin/master
git rebase origin/master

echo "Looking for new gem versions"
rm Gemfile.lock
export BUNDLE_APP_CONFIG=$(mktemp -d $TMPDIR/bundler_config_XXXXXX)
export BUNDLE_CACHE_PATH="vendor/package"
export BUNDLE_WITHOUT="development:test"
bundle package
rm -rf $BUNDLE_APP_CONFIG $BUNDLE_CACHE_PATH

git diff --exit-code Gemfile.lock || exit_code=$?
if [ -v exit_code ]; then
echo "Running unit tests"
bundle install
bundle exec rspec spec/unit/*

echo "Creating new pull request"
  git add .
  git commit -m "Bump gems"
else
echo "No new gem versions found"
fi
