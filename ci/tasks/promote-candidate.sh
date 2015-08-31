#!/usr/bin/env bash

set -e -x

source bosh-cpi-release/ci/tasks/utils.sh

ensure_not_replace_value aws_access_key_id
ensure_not_replace_value aws_secret_access_key

# Creates an integer version number from the semantic version format
# May be changed when we decide to fully use semantic versions for releases
integer_version=`cut -d "." -f1 release-version-semver/number`
echo $integer_version > integer_version

cd bosh-cpi-release

source /etc/profile.d/chruby-with-ruby-2.1.2.sh

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
bosh finalize release ../bosh-cpi-dev-artifacts/*.tgz --version $integer_version

rm config/private.yml

git diff | cat
git add .

git config --global user.email cf-bosh-eng@pivotal.io
git config --global user.name CI
git commit -m "New final release v $integer_version"
