#!/usr/bin/env bash

set -e -x

source bosh-cpi-src-in/ci/tasks/utils.sh

ensure_not_replace_value stemcell_name
ensure_not_replace_value openstack_security_group
ensure_not_replace_value openstack_flavor_with_ephemeral_disk
ensure_not_replace_value openstack_flavor_with_no_ephemeral_disk
ensure_not_replace_value bosh_admin_password
ensure_not_replace_value bosh_director_public_ip
ensure_not_replace_value bosh_director_private_ip
ensure_not_replace_value bats_vm_floating_ip
ensure_not_replace_value private_key_data

ensure_not_replace_value primary_network_id
ensure_not_replace_value primary_network_cidr
ensure_not_replace_value primary_network_gateway
ensure_not_replace_value primary_network_range
ensure_not_replace_value primary_network_manual_ip
ensure_not_replace_value primary_network_second_manual_ip
ensure_not_replace_value primary_network_dhcp_pool

ensure_not_replace_value secondary_network_id
ensure_not_replace_value secondary_network_cidr
ensure_not_replace_value secondary_network_gateway
ensure_not_replace_value secondary_network_range
ensure_not_replace_value secondary_network_manual_ip
ensure_not_replace_value secondary_network_dhcp_pool

####
#
# TODO:
# - check that all environment variables defined in pipeline.yml are set
# - reference stemcell like vCloud bats job does
# - copy rogue vm check from vSphere pipeline
#
####

working_dir=$PWD

# checked by BATs environment helper (bosh-acceptance-tests.git/lib/bat/env.rb)
export BAT_STEMCELL="${working_dir}/stemcell/stemcell.tgz"
export BAT_VCAP_PRIVATE_KEY="$working_dir/keys/bats.pem"
export BAT_DIRECTOR=${bosh_director_public_ip}
export BAT_DIRECTOR_PASSWORD=${bosh_admin_password}
export BAT_VCAP_PASSWORD=${bosh_admin_password}
export BAT_DNS_HOST=${bosh_director_public_ip}
export BAT_INFRASTRUCTURE='openstack'
export BAT_NETWORKING='manual'

source /etc/profile.d/chruby.sh
chruby 2.1.2

bosh_vcap_password_hash=$(ruby -e 'require "securerandom";puts ENV["bosh_admin_password"].crypt("$6$#{SecureRandom.base64(14)}")')

mkdir -p $working_dir/keys
export BAT_VCAP_PRIVATE_KEY="$working_dir/keys/bats.pem"
echo "$private_key_data" > $BAT_VCAP_PRIVATE_KEY

eval $(ssh-agent)
chmod go-r $working_dir/keys/bats.pem
ssh-add $working_dir/keys/bats.pem

echo "using bosh CLI version..."
bosh version

bosh -n target ${bosh_director_public_ip}

export BAT_DEPLOYMENT_SPEC="${working_dir}/bats-config.yml"
cat > $BAT_DEPLOYMENT_SPEC <<EOF
---
cpi: openstack
properties:
  pool_size: 1
  instances: 1
  uuid: $(bosh status --uuid)
  vip: ${bats_vm_floating_ip}
  second_static_ip: ${primary_network_second_manual_ip}
  instance_type: ${openstack_flavor_with_ephemeral_disk}
  flavor_with_no_ephemeral_disk: ${openstack_flavor_with_no_ephemeral_disk}
  stemcell:
    name: ${stemcell_name}
    version: latest
  networks:
  - name: default
    static_ip: ${primary_network_manual_ip}
    type: manual
    cloud_properties:
      net_id: ${primary_network_id}
      security_groups: [${openstack_security_group}]
    cidr: ${primary_network_cidr}
    reserved: [${bosh_director_private_ip},${primary_network_dhcp_pool}]
    static: [${primary_network_range}]
    gateway: ${primary_network_gateway}
  - name: second
    static_ip: ${secondary_network_manual_ip}
    type: manual
    cloud_properties:
      net_id: ${secondary_network_id}
      security_groups: [${openstack_security_group}]
    cidr: ${secondary_network_cidr}
    reserved: [${secondary_network_dhcp_pool}]
    static: [${secondary_network_range}]
    gateway: ${secondary_network_gateway}
  password: ${bosh_vcap_password_hash}
EOF

cd bats
./write_gemfile

bundle install
bundle exec rspec spec
