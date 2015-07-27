#!/usr/bin/env bash

set -e -x

ensure_not_replace_value() {
  local name=$1
  local value=$(eval echo '$'$name)
  if [ "$value" == 'replace-me' ]; then
    echo "environment variable $name must be set"
    exit 1
  fi
}

ensure_not_replace_value bat_stemcell_name
ensure_not_replace_value openstack_bat_security_group
ensure_not_replace_value openstack_bats_default_network_id
ensure_not_replace_value openstack_bats_flavor_with_ephemeral_disk
ensure_not_replace_value openstack_bats_flavor_with_no_ephemeral_disk
ensure_not_replace_value openstack_bats_second_network_id
ensure_not_replace_value BAT_DIRECTOR
ensure_not_replace_value BAT_VCAP_PASSWORD
ensure_not_replace_value BAT_DNS_HOST
ensure_not_replace_value BAT_INFRASTRUCTURE
ensure_not_replace_value BAT_NETWORKING
ensure_not_replace_value BAT_CIDR
ensure_not_replace_value BAT_SECOND_CIDR
ensure_not_replace_value BAT_GATEWAY
ensure_not_replace_value BAT_SECOND_GATEWAY
ensure_not_replace_value BAT_STATIC_RANGE
ensure_not_replace_value BAT_VM_FLOATING_IP
ensure_not_replace_value BOSH_OPENSTACK_MANUAL_IP
ensure_not_replace_value BOSH_OPENSTACK_SECOND_MANUAL_IP
ensure_not_replace_value BAT_VCAP_PRIVATE_KEY

####
#
# TODO:
# - check that all environment variables defined in pipeline.yml are set
# - reference stemcell like vCloud bats job does
# - upload new keypair to bluebox/mirantis with `external-cpi` tag to tell which vms have been deployed by which ci
# - use heredoc to generate deployment spec
# - copy rogue vm check from vSphere pipeline
#
####

cpi_release_name=bosh-openstack-cpi
working_dir=$PWD

source /etc/profile.d/chruby.sh
chruby 2.1.2

eval $(ssh-agent)
chmod go-r $BAT_VCAP_PRIVATE_KEY
ssh-add $BAT_VCAP_PRIVATE_KEY

export BAT_STEMCELL="$working_dir/stemcell/stemcell.tgz"
export BAT_VCAP_PRIVATE_KEY="$PWD/$BAT_VCAP_PRIVATE_KEY"

echo "using bosh CLI version..."
bosh version

bosh -n target $BAT_DIRECTOR

# TODO double-check on second_static_ip - may be deprecated, unnecessary, as seems to be using the sane as the default static ip
export BAT_DEPLOYMENT_SPEC="${working_dir}/bats-config.yml"
cat > $BAT_DEPLOYMENT_SPEC <<EOF
---
cpi: openstack
properties:
  key_name: external-cpi
  pool_size: 1
  instances: 1
  uuid: $(bosh status --uuid)
  vip: ${BAT_VM_FLOATING_IP}
  second_static_ip: ${BOSH_OPENSTACK_MANUAL_IP}
  instance_type: ${openstack_bats_flavor_with_ephemeral_disk}
  flavor_with_no_ephemeral_disk: ${openstack_bats_flavor_with_no_ephemeral_disk}
  stemcell:
    name: ${bat_stemcell_name}
    version: latest
  networks:
  - name: default
    static_ip: ${BOSH_OPENSTACK_MANUAL_IP}
    type: manual
    cloud_properties:
      net_id: ${openstack_bats_default_network_id}
      security_groups: ['${openstack_bat_security_group}']
    cidr: ${BAT_CIDR}
    reserved: []
    static: [${BAT_STATIC_RANGE}]
    gateway: ${BAT_GATEWAY}
  - name: second
    static_ip: ${BOSH_OPENSTACK_SECOND_MANUAL_IP}
    type: manual
    cloud_properties:
      net_id: ${openstack_bats_second_network_id}
      security_groups: [${openstack_bat_security_group}]
    cidr: ${BAT_SECOND_CIDR}
    reserved: []
    static: [${BOSH_OPENSTACK_SECOND_MANUAL_IP}]
    gateway: ${BAT_SECOND_GATEWAY}
EOF

cd bats
bundle install
bundle exec rspec spec
