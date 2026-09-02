#!/bin/bash

set -e

BASE_DIR=$(pwd)

# Copy CI directory to output before apply so destroy has the terraform
# config and any partial state even if apply fails
cp -r "${BASE_DIR}/bosh-openstack-cpi-release/ci" "${BASE_DIR}/terraform-cpi"

pushd bosh-openstack-cpi-release/ci/terraform/ci/lifecycle
  terraform init

  set +e
  terraform apply -auto-approve -input=false
  apply_exit=$?
  set -e

  # Sync state to output regardless of apply result so ensure-destroy can run
  cp -f terraform.tfstate "${BASE_DIR}/terraform-cpi/ci/terraform/ci/lifecycle/" 2>/dev/null || true

  if [ $apply_exit -ne 0 ]; then
    exit $apply_exit
  fi

  # This subshell converts 'terraform output' output into JSON to be consumed by former clients of the Terraform Resource.
  # The only special Terraform construction its awk program handles is 'tolist'. The 'sed' program at the end is to remove
  # the "," from the last line of the awk output, because I don't know how to make 'awk' do something different on the LAST
  # line of the input.
  (
    echo "{"
    terraform output | awk -f "${BASE_DIR}/bosh-openstack-cpi-release/ci/tasks/convert-terraform-output-to-mostly-json.awk" | sed -e '$ s/,$//'
    echo "}"
  ) > "${BASE_DIR}/terraform-cpi/metadata"
popd

echo ""
echo "******************************"
echo "Metadata JSON passed to subsequent tests:"
cat terraform-cpi/metadata
echo "******************************"
