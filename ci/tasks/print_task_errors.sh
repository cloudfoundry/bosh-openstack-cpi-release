#!/usr/bin/env bash

set -e

source bosh-openstack-cpi-release/ci/tasks/utils.sh

export_terraform_variable terraform-cpi/metadata "director_public_ip"
export BOSH_ENVIRONMENT=${director_public_ip}
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=$(bosh-go int bosh-director-deployment/credentials.yml  --path /admin_password)
export BOSH_CA_CERT="$(bosh-go int bosh-director-deployment/credentials.yml --path /director_ssl/ca)"

bosh-go -n tasks --all --recent=100

echo 'Printing debug output of tasks in state error, latest errors first'

bosh-go -n tasks --all --recent=100 --json | ./bosh-openstack-cpi-release/ci/ruby_scripts/print_task_debug_output.sh
