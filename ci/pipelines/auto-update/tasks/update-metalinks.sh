#!/usr/bin/env bash

set -e
set -x

cp -r metalink-src-in/. metalink-src-out
cd metalink-src-out/


# Update rubygems
rubygems_version=$(
git ls-remote --tags https://github.com/rubygems/rubygems.git \
  | cut -f2 \
  | grep -v '\^{}' \
  | grep -E '^refs/tags/.+$' \
  | sed  -E 's/^refs\/tags\/(.+)$/\1/'  \
  | sed  's/^v//' \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
  | sort -r --version-sort \
  | head -n1
)
rubygems_url=https://rubygems.org/rubygems/rubygems-${rubygems_version}.tgz
rubygems_size=$( curl --silent --head "${rubygems_url}" | grep Content-Length | awk '{ print $2 }' | tr -cd '[:digit:]' )

cat > rubygems_metalink<<EOF
<?xml version="1.0" encoding="utf-8"?>
<repository xmlns="https://dpb587.github.io/metalink-repository/schema-0.1.0.xsd">
    <metalink xmlns="urn:ietf:params:xml:ns:metalink">
      <file name="rubygems-${rubygems_version}.tar.gz">
        <size>${rubygems_size}</size>
        <url>${rubygems_url}</url>
        <version>${rubygems_version}</version>
      </file>
    </metalink>
</repository>
EOF

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
