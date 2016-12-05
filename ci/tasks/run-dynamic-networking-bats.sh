#!/usr/bin/env bash

set -x

source bosh-cpi-src-in/ci/tasks/utils.sh

ensure_not_replace_value stemcell_name
ensure_not_replace_value bosh_admin_password
ensure_not_replace_value openstack_flavor_with_ephemeral_disk
ensure_not_replace_value openstack_flavor_with_no_ephemeral_disk
ensure_not_replace_value private_key_data
optional_value availability_zone

working_dir=$PWD

mkdir -p $working_dir/keys
export BAT_VCAP_PRIVATE_KEY="$working_dir/keys/bats.pem"
echo "$private_key_data" > $BAT_VCAP_PRIVATE_KEY

eval $(ssh-agent)
chmod go-r $BAT_VCAP_PRIVATE_KEY
ssh-add $BAT_VCAP_PRIVATE_KEY

source /etc/profile.d/chruby.sh
chruby 2.1.2

#copy terraform metadata in order to use it in 'print_task_errors' and 'teardown_director' task
# where no distinction is made between manual and dynamic
cp terraform-bats-dynamic-deploy/metadata terraform-bats
metadata=terraform-bats/metadata

export_terraform_variable "floating_ip"
export_terraform_variable "director_public_ip"
export_terraform_variable "primary_net_id"
export_terraform_variable "security_group"

bosh_vcap_password_hash=$(ruby -e 'require "securerandom";puts ENV["bosh_admin_password"].crypt("$6$#{SecureRandom.base64(14)}")')

# checked by BATs environment helper (bosh-acceptance-tests.git/lib/bat/env.rb)
export BAT_STEMCELL="${working_dir}/stemcell/stemcell.tgz"
export BAT_DIRECTOR=${director_public_ip}
export BAT_DIRECTOR_PASSWORD=${bosh_admin_password}
export BAT_VCAP_PASSWORD=${bosh_admin_password}
export BAT_DNS_HOST=${director_public_ip}
export BAT_INFRASTRUCTURE='openstack'
export BAT_NETWORKING='dynamic'

echo "using bosh CLI version..."
bosh version

bosh -n target $director_public_ip

export BAT_DEPLOYMENT_SPEC="${working_dir}/bats-config.yml"
cat > $BAT_DEPLOYMENT_SPEC <<EOF
---
cpi: openstack
properties:
  uuid: $(bosh status --uuid)
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
./write_gemfile

bundle install
bundle exec rspec --tag ~manual_networking --tag ~raw_ephemeral_storage spec
