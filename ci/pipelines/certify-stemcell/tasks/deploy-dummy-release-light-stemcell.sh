#!/usr/bin/env bash

set -e

source bosh-cpi-src-in/ci/tasks/utils.sh

ensure_not_replace_value bosh_admin_password
ensure_not_replace_value bosh_director_ip
ensure_not_replace_value dns
ensure_not_replace_value v3_e2e_security_group
ensure_not_replace_value os_name
ensure_not_replace_value network_id
ensure_not_replace_value instance_flavor

source /etc/profile.d/chruby.sh
chruby 2.1.2

init_openstack_cli_env

verify_image_in_openstack() {
  echo "Verify that image with ID $image_id exists in OpenStack..."
  openstack image show $image_id || image_not_found=$?
  if [ $image_not_found ]; then
    echo "failed to get image details"
    exit 1
  fi
}

stemcell_version=$(cat stemcell/version)
#image_id=$(cat deployment/e2e-director-manifest-state.json | jq --raw-output ".stemcells[0].cid")
image_id=2ec8bc28-1fe0-4387-9453-a4b0a1d508e6
deployment_dir="${PWD}/dummy-deployment"
manifest_filename="dummy-manifest.yml"
dummy_release_name="dummy"
bosh_vcap_password_hash=$(ruby -e 'require "securerandom";puts ENV["bosh_admin_password"].crypt("$6$#{SecureRandom.base64(14)}")')

verify_image_in_openstack

echo "setting up artifacts used in $manifest_filename"
mkdir -p ${deployment_dir}

echo "using bosh CLI version..."
bosh version

echo "targeting bosh director at ${bosh_director_ip}"
bosh -n target ${bosh_director_ip}
bosh login admin ${bosh_admin_password}

echo "generating light stemcell ..."
create_light_stemcell_command="./bosh-cpi-src-in/scripts/create_light_stemcell --version $stemcell_version --os $os_name --image-id $image_id"
echo $create_light_stemcell_command
$create_light_stemcell_command
#./bosh-cpi-src-in/scripts/create_light_stemcell --version $stemcell_version --os $os_name --image-id $image_id

echo "uploading stemcell to director..."
bosh -n upload stemcell "light-bosh-stemcell-${stemcell_version}-openstack-kvm-${os_name}-go_agent.tgz"

pushd dummy-release
  echo "creating release..."
  bosh -n create release --name ${dummy_release_name}

  echo "uploading release to director..."
  bosh -n upload release --skip-if-exists
popd


#create dummy release manifest as heredoc
cat > "${deployment_dir}/${manifest_filename}"<<EOF
---
name: dummy
director_uuid: $(bosh status --uuid)

releases:
  - name: ${dummy_release_name}
    version: latest

resource_pools:
  - name: default
    stemcell:
      name: "bosh-openstack-kvm-${os_name}-go_agent"
      version: latest
    network: private
    size: 1
    cloud_properties:
      instance_type: ${instance_flavor}
      disk: 1024
    env:
      bosh:
        password: ${bosh_vcap_password_hash}

networks:
  - name: private
    type: dynamic
    dns: ${dns}
    cloud_properties:
      net_id: ${network_id}
      security_groups: [${v3_e2e_security_group}]

jobs:
  - name: dummy
    template: dummy
    instances: 1
    resource_pool: default
    networks:
      - name : private
        default: [dns, gateway]

compilation:
  reuse_compilation_vms: true
  workers: 1
  network: private
  cloud_properties:
    instance_type: ${instance_flavor}

update:
  canaries: 1
  canary_watch_time: 30000-240000
  update_watch_time: 30000-600000
  max_in_flight: 3
EOF

pushd ${deployment_dir}
  echo "deploying dummy release..."
  bosh deployment ${manifest_filename}
  bosh -n deploy
  bosh -n delete deployment dummy
  bosh -n cleanup --all
  bosh -n stemcells 2>&1 | grep "No stemcells" || stemcells_found=$?
  if [ $stemcells_found ]; then
    echo "failed to delete stemcell"
    exit 1
  fi
  verify_image_in_openstack
popd
