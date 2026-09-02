#!/bin/bash

set -e

BASE_DIR=$(pwd)

pushd bosh-openstack-cpi-release/ci/terraform/ci/lifecycle
  terraform init

  # Copy CI directory after init so the .terraform/ provider cache is included;
  # destroy task runs without re-initializing
  cp -r "${BASE_DIR}/bosh-openstack-cpi-release/ci" "${BASE_DIR}/terraform-cpi"

  set +e
  terraform apply -auto-approve -input=false
  apply_exit=$?
  set -e

  # Sync state to output so ensure-destroy has it; skip silently only if no state file exists
  set +e
  [ -f terraform.tfstate ] && cp -f terraform.tfstate "${BASE_DIR}/terraform-cpi/ci/terraform/ci/lifecycle/"
  state_copy_exit=$?
  set -e

  if [ $apply_exit -ne 0 ] || [ $state_copy_exit -ne 0 ]; then
    echo "{}" > "${BASE_DIR}/terraform-cpi/metadata"
    exit $((apply_exit != 0 ? apply_exit : state_copy_exit))
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

