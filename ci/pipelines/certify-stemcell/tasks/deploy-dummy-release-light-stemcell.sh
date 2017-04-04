#!/usr/bin/env bash

set -e

source bosh-cpi-src-in/ci/tasks/utils.sh

: ${bosh_admin_password:?}
: ${os_name:?}
: ${instance_flavor:?}

metadata=terraform/metadata

export_terraform_variable "director_public_ip"
export_terraform_variable "dns"
export_terraform_variable "v3_e2e_net_id"
export_terraform_variable "v3_e2e_security_group"

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
image_id=$(cat deployment/e2e-director-manifest-state.json | jq --raw-output ".stemcells[0].cid")
deployment_dir="${PWD}/deployment"
manifest_filename="dummy-light-stemcell-manifest.yml"
dummy_release_name="dummy"
deployment_name="dummy-light-stemcell"
bosh_vcap_password_hash=$(ruby -e 'require "securerandom";puts ENV["bosh_admin_password"].crypt("$6$#{SecureRandom.base64(14)}")')

verify_image_in_openstack

cd ${deployment_dir}

echo "using bosh CLI version..."
bosh-go --version

export BOSH_ENVIRONMENT=${director_public_ip}
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=${bosh_admin_password}
export BOSH_CA_CERT=director_ca

echo "generating light stemcell ..."
create_light_stemcell_command="../bosh-cpi-src-in/scripts/create_light_stemcell --version $stemcell_version --os $os_name --image-id $image_id"
echo $create_light_stemcell_command
$create_light_stemcell_command

echo "uploading stemcell to director..."
bosh-go -n upload-stemcell "light-bosh-stemcell-${stemcell_version}-openstack-kvm-${os_name}-go_agent.tgz"

echo "creating dummy release..."
bosh-go -n create-release --dir ../dummy-release --name ${dummy_release_name}

echo "uploading release to director..."
bosh-go -n upload-release --dir ../dummy-release

#create dummy release manifest as heredoc
cat > "${manifest_filename}"<<EOF
---
name: ${deployment_name}

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
    dns: [${dns}]
    cloud_properties:
      net_id: ${v3_e2e_net_id}
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

echo "deploying dummy release..."
bosh-go -n deploy -d ${deployment_name} ${manifest_filename}

echo "deleting dummy deployment and light stemcell..."
bosh-go -n delete-deployment -d ${deployment_name}
bosh-go -n clean-up --all
bosh-go -n stemcells 2>&1 | grep "No stemcells" || stemcells_found=$?
if [ $stemcells_found ]; then
    echo "failed to delete stemcell"
    exit 1
fi

verify_image_in_openstack
