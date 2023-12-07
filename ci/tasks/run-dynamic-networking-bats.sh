#!/usr/bin/env bash

set -x

source bosh-openstack-cpi-release/ci/tasks/utils.sh

: ${stemcell_name:?}
: ${openstack_flavor_with_ephemeral_disk:?}
: ${openstack_flavor_with_no_ephemeral_disk:?}

optional_value availability_zone
optional_value bats_rspec_tags

working_dir=$PWD

#copy terraform metadata in order to use it in 'print_task_errors' and 'teardown_director' task
# where no distinction is made between manual and dynamic
cp terraform-cpi-deploy/metadata terraform-bats
metadata=terraform-bats/metadata

export_terraform_variable "floating_ip"
export_terraform_variable "director_public_ip"
export_terraform_variable "primary_net_id"
export_terraform_variable "security_group"

if [ ! -f "${working_dir}/stemcell/stemcell.tgz" ]; then
  #  only needed for registry removal
  mv ${working_dir}/stemcell/*.tgz ${working_dir}/stemcell/stemcell.tgz
fi

export BAT_STEMCELL="${working_dir}/stemcell/stemcell.tgz"
export BAT_DIRECTOR=${director_public_ip}
export BAT_INFRASTRUCTURE='openstack'
export BAT_BOSH_CLI='bosh-go'

export BOSH_ENVIRONMENT="$( manifest_path /instance_groups/name=bosh/networks/name=public/static_ips/0 2>/dev/null )"
export BOSH_CLIENT="admin"
export BOSH_CLIENT_SECRET="$( creds_path /admin_password )"
export BOSH_CA_CERT="$( creds_path /director_ssl/ca )"

echo "using bosh CLI version..."
bosh-go --version

export BAT_DEPLOYMENT_SPEC="${working_dir}/bats-config.yml"
cat > $BAT_DEPLOYMENT_SPEC <<EOF
---
cpi: openstack
properties:
  vip: ${floating_ip}
  instance_type: ${openstack_flavor_with_ephemeral_disk}
  availability_zone: ${availability_zone:-"~"}
  pool_size: 1
  instances: 1
  flavor_with_no_ephemeral_disk: ${openstack_flavor_with_no_ephemeral_disk}
  ssh_key_pair:
    public_key: "$( creds_path /jumpbox_ssh/public_key )"
    private_key: "$(creds_path /jumobox_ssh/private_key | sed 's/$/\\n/' | tr -d '\n')"
  stemcell:
    name: ${stemcell_name}
    version: latest
  networks:
    - name: default
      type: dynamic
      cloud_properties:
        net_id: ${primary_net_id}
        security_groups: [${security_group}]
EOF

cd bats
bundle install -j4
bundle exec rspec --tag ~manual_networking --tag ~raw_ephemeral_storage ${bats_rspec_tags} spec
