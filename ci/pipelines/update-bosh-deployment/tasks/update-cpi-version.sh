#!/usr/bin/env bash

set -e
set -x

export TERM=xterm-256color

cp -r bosh-deployment-src/. bosh-deployment-fork
URL=$(cat ./bosh-openstack-cpi-release/url)
VERSION=$(cat ./bosh-openstack-cpi-release/version)
SHA=$(cat ./bosh-openstack-cpi-release/sha1)-fake
cd bosh-deployment-fork
sed -i'' "/bosh-openstack-cpi/,+3s|url: .*$|url: $URL|" openstack/cpi.yml
sed -i'' "/bosh-openstack-cpi/,+3s|version: .*$|version: \"$VERSION\"|" openstack/cpi.yml
sed -i'' "/bosh-openstack-cpi/,+3s|sha1: .*$|sha1: $SHA|" openstack/cpi.yml
git config --global user.email cf-bosh-eng@pivotal.io
git config --global user.name CI

git diff
git add openstack/cpi.yml
git commit -m "bump openstack CPI" || true
