#!/usr/bin/env bash

set -e

source bosh-cpi-src-in/ci/tasks/utils.sh

: ${bosh_admin_password:?}

metadata=terraform-bats/metadata

export_terraform_variable "director_public_ip"
echo -e "${director_ca}" > director_ca
export BOSH_ENVIRONMENT=${director_public_ip}
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=${bosh_admin_password}
export BOSH_CA_CERT=director_ca

bosh-go -n tasks --all --recent=100

echo 'Printing debug output of tasks in state error, latest errors first'

bosh-go -n tasks --all --recent=100 --json | ./bosh-cpi-src-in/ci/ruby_scripts/print_task_debug_output.sh
