#!/usr/bin/env bash

set -e
set -x

cp -r metalink-src-in/. metalink-src-out
cd metalink-src-out/



echo "Looking for new package versions of libyaml, bundler, or rubygems"
git add .
git diff --cached --exit-code || exit_code=$?
if [ -v exit_code ]; then
echo "Creating new commit request"
  git add .
  git config --global user.email cf-bosh-eng@pivotal.io
  git config --global user.name CI
  git commit -m "Bump package version"
else
echo "No new libyaml, bundler, or rubygems version found"
fi
