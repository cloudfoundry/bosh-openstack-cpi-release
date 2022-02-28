#!/usr/bin/env bash

set -e

source bosh-cpi-src-in/ci/tasks/utils.sh

: ${bosh_vcap_password:?}
: ${stemcell_name:?}
: ${instance_flavor:?}

metadata=terraform/metadata

export_terraform_variable "director_public_ip"
export_terraform_variable "dns"
export_terraform_variable "v3_e2e_security_group"
export_terraform_variable "v3_e2e_net_id"

director_deployment_input="${PWD}/director-deployment"
dummy_deployment_output="${PWD}/dummy-deployment"
manifest_filename="dummy-manifest.yml"
director_cloud_config="cloud-config.yml"
dummy_release_name="dummy"
bosh_vcap_password_hash=$(mkpasswd -m sha-512 -S $(dd if=/dev/random count=10 bs=1 | base32) "${bosh_vcap_password}")

cd ${director_deployment_input}

export BOSH_ENVIRONMENT=${director_public_ip}
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=$(bosh-go int credentials.yml  --path /admin_password)
export BOSH_CA_CERT=director_ca

echo "using bosh CLI version..."
bosh-go --version

echo "uploading stemcell to director..."
bosh-go -n upload-stemcell ../stemcell/stemcell.tgz

cat > "${dummy_deployment_output}/${director_cloud_config}"<<EOF
---
compilation:
  reuse_compilation_vms: true
  workers: 1
  network: private
  cloud_properties:
    instance_type: ${instance_flavor}

networks:
  - name: private
    type: dynamic
    dns: ${dns}
    cloud_properties:
      net_id: ${v3_e2e_net_id}
      security_groups: [${v3_e2e_security_group}]

vm_types:
  - name: default
    cloud_properties:
      instance_type: ${instance_flavor}
      disk: 1024
EOF
echo "uploading cloud-config..."
bosh-go -n update-cloud-config ${dummy_deployment_output}/${director_cloud_config}

echo "creating release..."
bosh-go -n create-release --dir ../dummy-release --name ${dummy_release_name}

echo "uploading release to director..."
bosh-go -n upload-release --dir ../dummy-release

#create dummy release manifest as heredoc
cat > "${dummy_deployment_output}/${manifest_filename}"<<EOF
---
name: dummy

releases:
  - name: ${dummy_release_name}
    version: latest

instance_groups:
  - name: dummy
    instances: 1
    jobs:
      - name: dummy
        release: ${dummy_release_name}
    vm_type: default
    stemcell: ubuntu
    networks:
      - name: private
        default: [dns, gateway]
    env:
      bosh:
        password: ${bosh_vcap_password_hash}

stemcells:
- alias: ubuntu
  version: latest
  name: ${stemcell_name}

update:
  canaries: 1
  canary_watch_time: 30000-240000
  update_watch_time: 30000-600000
  max_in_flight: 3
EOF

echo "deploying dummy release..."
bosh-go -n deploy -d dummy ${dummy_deployment_output}/${manifest_filename}
if [ "${delete_deployment_when_done}" = "true" ]; then
    bosh-go -n delete-deployment -d dummy
    bosh-go -n clean-up --all
fi
