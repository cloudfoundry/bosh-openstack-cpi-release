#!/usr/bin/env bash

set -e
set -x

cp -r bosh-cpi-src-out bosh-cpi-src-updated-packages-out/repo
#
#cd bosh-cpi-src-out/repo/src/bosh_openstack_cpi
#echo "Looking for new gem versions"
#rm Gemfile.lock
#./vendor_gems
#git diff --exit-code Gemfile.lock || exit_code=$?
#if [ -v exit_code ]; then
#echo "Running unit tests"
#bundle install
#bundle exec rspec spec/unit/*
#
#echo "Creating new pull request"
#  git add .
#  git config --global user.email cf-bosh-eng@pivotal.io
#  git config --global user.name CI
#  git commit -m "Bump gems"
#else
#echo "No new gem versions found"
#fi
