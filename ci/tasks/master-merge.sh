#!/bin/sh

set -e -x

cd bosh-cpi-release-master

git checkout wip/promote-develop-95585962

git config --global user.email "cf-bosh-eng+bosh-ci@pivotal.io"
git config --global user.name "bosh-ci"

git merge --no-edit wip/promote-master-95585962
