#!/usr/bin/env bash

set -e
set -x

echo "Check if latest auto-update commit has already been merged to master"
pr_open=$(git branch master --contains $(git rev-parse origin/auto-update))
if [ -z ${pr_open} ]; then
  echo "Creating pull-request"
  cd bosh-cpi-src-out
  hub pull-request -b master -h auto-update-m "Bump gems"
fi
