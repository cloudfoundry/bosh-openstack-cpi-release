#!/usr/bin/env bash

set -e -x

# put all blobs together
mkdir blobs
cp libyaml-test/yaml-*.tar.gz blobs
cp bundler-blob/bundler-*.gem blobs
cp rubygems-blob/rubygems-*.tar.gz blobs
cp ruby/ruby-*.tar.gz blobs


cp -r packages-src-in/. packages-src-out
cd packages-src-out
git config --global user.email cf-bosh-eng@pivotal.io
git config --global user.name CI
git fetch origin master:refs/remotes/origin/master
git rebase origin/master

#
# update blobs
#
for blob in $( bosh-go blobs --column=path | grep "^ruby_openstack_cpi/" | sed "s#ruby_openstack_cpi/##g" ); do
  if [[ ! -e "../blobs/$blob" ]]; then
    blob_name=$(echo $blob | cut -f1 -d"-")
    new_blob=$(find ../blobs -name "${blob_name}-*" -type f | cut -f3 -d"/")

    #update blob
    bosh-go remove-blob "ruby_openstack_cpi/$blob"
    bosh-go add-blob "../blobs/$new_blob" "ruby_openstack_cpi/$new_blob"

    #update package
    blob_name_with_version=$( echo ${blob} | sed -E "s/(${blob_name}-[0-9]+\.[0-9]+\.[0-9]+).+$/\1/" )
    new_blob_name_with_version=$( echo ${new_blob} | sed -E "s/(${blob_name}-[0-9]+\.[0-9]+\.[0-9]+).+$/\1/" )

    sed -i "s/${blob_name_with_version}/${new_blob_name_with_version}/g" packages/ruby_openstack_cpi/packaging
    sed -i "s/${blob_name_with_version}/${new_blob_name_with_version}/g" packages/ruby_openstack_cpi/spec

    #migrate rubygems from .tgz to .tar.gz
    sed -i "s/\(rubygems.*\)\.tgz/\1\.tar\.gz/g" packages/ruby_openstack_cpi/packaging
    sed -i "s/\(rubygems.*\)\.tgz/\1\.tar\.gz/g" packages/ruby_openstack_cpi/spec
  fi
done

git add .
git diff --cached --exit-code || exit_code=$?
if [ -v exit_code ]; then
  echo "creating config/private.yml with blobstore secrets"
  cat > config/private.yml << EOF
---
blobstore:
  provider: s3
  options:
    access_key_id: $aws_access_key_id
    secret_access_key: $aws_secret_access_key
EOF

  bosh-go upload-blobs
  echo "Creating new commit request"
  git add .
  git commit -m "Bump package blob versions"

else
echo "No new packages found"
fi
