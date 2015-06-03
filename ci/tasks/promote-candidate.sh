#!/usr/bin/env bash

set -e -x

ensure_not_replace_value() {
  local name=$1
  local value=$(eval echo '$'$name)
  if [ "$value" == 'replace-me' ]; then
    echo "environment variable $name must be set"
    exit 1
  fi
}

ensure_not_replace_value aws_access_key_id
ensure_not_replace_value aws_secret_access_key

cd bosh-cpi-release

source /etc/profile.d/chruby-with-ruby-2.1.2.sh

git config --global user.email cf-bosh-eng@pivotal.io
git config --global user.name CI

git merge --no-edit wip/promote-master-95585962

set +x
echo creating config/private.yml with blobstore secrets
cat > config/private.yml << EOF
---
blobstore:
  s3:
    access_key_id: $aws_access_key_id
    secret_access_key: $aws_secret_access_key
EOF
set -x

echo "using bosh CLI version..."
bosh version

echo "finalizing CPI release..."
bosh finalize release ../bosh-cpi-dev-artifacts/*.tgz

rm config/private.yml

version=`git diff releases/*/index.yml | grep -E "^\+.+version" | sed s/[^0-9]*//g`
git diff | cat
git add .

git commit -m "New final release v $version"
