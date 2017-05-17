#!/usr/bin/env bash

set -e

source bosh-cpi-src-in/ci/tasks/utils.sh

: ${bosh_admin_password:?}

metadata=terraform-bats/metadata

export_terraform_variable "director_public_ip"
echo -e "${director_ca}" > director_ca

echo 'Printing debug output of tasks in state error'

bosh-go -n -e ${director_public_ip} \
  --client admin \
  --client-secret ${bosh_admin_password} \
  --ca-cert director_ca \
  tasks --all --recent=100 | ./bosh-cpi-src-in/ci/ruby_scripts/print_task_debug_output.sh
