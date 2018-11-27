#!/usr/bin/env bash

set -x

source bosh-cpi-src-in/ci/tasks/utils.sh

: ${stemcell_name:?}
: ${bosh_vcap_password:?}
: ${openstack_flavor_with_ephemeral_disk:?}
: ${openstack_flavor_with_no_ephemeral_disk:?}
: ${private_key_data:?}

optional_value availability_zone

working_dir=$PWD

mkdir -p $working_dir/keys
export BAT_VCAP_PRIVATE_KEY="$working_dir/keys/bats.pem"
echo "$private_key_data" > $BAT_VCAP_PRIVATE_KEY

eval $(ssh-agent)
chmod go-r $BAT_VCAP_PRIVATE_KEY
ssh-add $BAT_VCAP_PRIVATE_KEY

#copy terraform metadata in order to use it in 'print_task_errors' and 'teardown_director' task
# where no distinction is made between manual and dynamic
cp terraform-cpi-deploy/metadata terraform-bats
metadata=terraform-bats/metadata

export_terraform_variable "floating_ip"
export_terraform_variable "director_public_ip"
export_terraform_variable "primary_net_id"
export_terraform_variable "security_group"

bosh_vcap_password_hash=$(ruby -rsecurerandom -e 'puts ENV["bosh_vcap_password"].crypt("$6$#{SecureRandom.base64(14)}")')

if [ ! -f "${working_dir}/stemcell/stemcell.tgz" ]; then
  #  only needed for registry removal
  mv ${working_dir}/stemcell/*.tgz ${working_dir}/stemcell/stemcell.tgz
fi

export BAT_STEMCELL="${working_dir}/stemcell/stemcell.tgz"
export BAT_DIRECTOR=${director_public_ip}
export BAT_DNS_HOST=${director_public_ip}
export BAT_INFRASTRUCTURE='openstack'
export BAT_NETWORKING='dynamic'
export BAT_BOSH_CLI='bosh-go'
export BAT_PRIVATE_KEY="not-needed-key"

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
  stemcell:
    name: ${stemcell_name}
    version: latest
  networks:
    - name: default
      type: dynamic
      cloud_properties:
        net_id: ${primary_net_id}
        security_groups: [${security_group}]
  password: ${bosh_vcap_password_hash}
EOF

cd bats
bundle install -j4
bundle exec rspec --tag ~manual_networking --tag ~raw_ephemeral_storage spec
