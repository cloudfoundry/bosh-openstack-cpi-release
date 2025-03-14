#!/bin/bash

set -e

BASE_DIR=`pwd`

pushd bosh-openstack-cpi-release/ci/terraform/ci/bats-manual
  terraform init
  terraform apply -auto-approve -input=false
  cp -r ${BASE_DIR}/bosh-openstack-cpi-release/ci ${BASE_DIR}/terraform-cpi
  # Write out the 'terraform output' data as JSON, as the terraform-resource would:
  (echo "{"; terraform output | sed -e 's/\(.*\) =/"\1": /' -e '$ ! s/$/,/'; echo "}") > ${BASE_DIR}/terraform-cpi/metadata
popd

echo ""
echo "******************************"
echo "Metadata JSON passed to subsequent tests:"
cat terraform-cpi/metadata
echo "******************************"