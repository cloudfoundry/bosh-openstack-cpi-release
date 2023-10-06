#!/usr/bin/env bash

set -e
source bosh-openstack-cpi-release/ci/tasks/utils.sh

: ${publish_api_calls_enabled:?}

cp -r bosh-openstack-cpi-release publish/repo

cd publish/repo/ci/ruby_scripts

bundle install
bundle exec rspec spec/
bundle exec get_api_calls < ../../../../lifecycle-log/lifecycle.log > ../../docs/openstack-api-calls.md

git diff | cat

if [ "$publish_api_calls_enabled" = "true" ]; then
    git diff --exit-code --quiet ../../docs/openstack-api-calls.md || exit_code=$?
    if [ -v exit_code ]; then
      git add ../../docs/openstack-api-calls.md

      git config --global user.email cf-bosh-eng@pivotal.io
      git config --global user.name CI
      git commit -m "Update openstack api calls tracking"
    fi
else
    git reset --hard HEAD
fi
