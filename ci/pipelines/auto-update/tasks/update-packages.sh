#!/usr/bin/env bash

set -e -x

basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../../.." && pwd )"


target=$(readlink -f ruby-*)
rubydir="${target##*/}"

mkdir unpacked-ruby-release
pushd "${rubydir}"
  tar xfz "v$(cat .resource/version)" -C "${basedir}"/unpacked-ruby-release --strip-components=1
popd

cp -r packages-src-in/. packages-src-out
cd packages-src-out

git config --global user.email cf-bosh-eng@pivotal.io
git config --global user.name CI
git fetch origin master:refs/remotes/origin/master
git rebase origin/master


echo "-----> [$(date)]: Run bosh vendor package"

cat > config/private.yml << EOF
---
blobstore:
  provider: s3
  options:
    access_key_id: $aws_access_key_id
    secret_access_key: $aws_secret_access_key
EOF

rm -r packages/ruby-*

ruby_package_version="$(grep name "${basedir}"/unpacked-ruby-release/packages/"${rubydir}"-r*/spec | awk '{print $2}')"
bosh-go vendor-package "$ruby_package_version" "${basedir}"/unpacked-ruby-release


echo "-----> [$(date)]: Rendering package and job templates"

git rm packages/bosh_openstack_cpi/packaging && :
git rm packages/bosh_openstack_cpi/spec && :
git rm jobs/openstack_cpi/templates/cpi.erb && :
git rm jobs/openstack_cpi/spec && :


erb "ruby_package_version=${ruby_package_version}" "ci/templates/packages/bosh_openstack_cpi/spec.erb" > "packages/bosh_openstack_cpi/spec"
erb "ruby_package_version=${ruby_package_version}" "ci/templates/packages/bosh_openstack_cpi/packaging.erb" > "packages/bosh_openstack_cpi/packaging"
erb "ruby_package_version=${ruby_package_version}" "ci/templates/jobs/openstack_cpi/cpi.erb.erb" > "jobs/openstack_cpi/templates/cpi.erb"
erb "ruby_package_version=${ruby_package_version}" "ci/templates/jobs/openstack_cpi/spec.erb" > "jobs/openstack_cpi/spec"


echo "-----> [$(date)]: Creating git commit"

git add .
git --no-pager diff --cached

if [[ "$( git status --porcelain )" != "" ]]; then
  git commit -am "Bump ruby release to ${ruby_package_version}"
fi
