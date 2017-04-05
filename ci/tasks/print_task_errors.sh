#!/usr/bin/env bash

set -e

source bosh-cpi-src-in/ci/tasks/utils.sh

: ${bosh_admin_password:?}

metadata=terraform-bats/metadata

export_terraform_variable "director_public_ip"

echo 'Printing debug output of tasks in state error'

cd bosh-cpi-src-in/ci/ruby_scripts

bosh-go -n -e ${director_public_ip} \
  --client admin \
  --client-secret ${bosh_admin_password} \
  tasks --all --recent 100 | ./print_task_debug_output.sh
