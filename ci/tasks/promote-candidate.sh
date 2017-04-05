#!/usr/bin/env bash

set -e -x

source bosh-cpi-src-in/ci/tasks/utils.sh

: ${aws_access_key_id:?}
: ${aws_secret_access_key:?}

# Creates an integer version number from the semantic version format
# May be changed when we decide to fully use semantic versions for releases
integer_version=`cut -d "." -f1 release-version-semver/number`
echo $integer_version > promote/integer_version

cp -r bosh-cpi-src-in promote/repo

cd promote/repo

set +x
echo "creating config/private.yml with blobstore secrets"
cat > config/private.yml << EOF
---
blobstore:
  provider: s3
  options:
    access_key_id: $aws_access_key_id
    secret_access_key: $aws_secret_access_key
EOF
set -x

echo "using bosh CLI version..."
bosh-go --version

echo "finalizing CPI release..."
bosh-go finalize-release --version $integer_version ../../bosh-cpi-dev-artifacts/*.tgz

rm config/private.yml

git diff | cat
git add .

git config --global user.email cf-bosh-eng@pivotal.io
git config --global user.name CI
git commit -m "New final release v$integer_version"
