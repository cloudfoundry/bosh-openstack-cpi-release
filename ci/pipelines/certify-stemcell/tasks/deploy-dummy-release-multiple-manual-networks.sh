#!/usr/bin/env bash

set -e

source bosh-cpi-src-in/ci/tasks/utils.sh

: ${bosh_vcap_password:?}
: ${v3_e2e_private_key_data:?}
: ${stemcell_name:?}
: ${instance_flavor:?}

metadata=terraform/metadata

export_terraform_variable "director_public_ip"
export_terraform_variable "dns"
export_terraform_variable "v3_e2e_security_group"
export_terraform_variable "v3_e2e_net_id"
export_terraform_variable "network_no_dhcp_1_id"
export_terraform_variable "network_no_dhcp_1_range"
export_terraform_variable "network_no_dhcp_1_gateway"
export_terraform_variable "network_no_dhcp_1_ip"
export_terraform_variable "network_no_dhcp_2_id"
export_terraform_variable "network_no_dhcp_2_range"
export_terraform_variable "network_no_dhcp_2_gateway"
export_terraform_variable "network_no_dhcp_2_ip"

deployment_dir="${PWD}/director-deployment"
manifest_filename="dummy-multiple-manual-networks-manifest.yml"
dummy_release_name="dummy"
deployment_name="dummy-multiple-manual-networks"
bosh_vcap_password_hash=$(ruby -e 'require "securerandom";puts ENV["bosh_vcap_password"].crypt("$6$#{SecureRandom.base64(14)}")')

cd ${deployment_dir}

export BOSH_ENVIRONMENT=${director_public_ip}
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=$(bosh-go int credentials.yml  --path /admin_password)
export BOSH_CA_CERT=director_ca

echo "using bosh CLI version..."
bosh-go --version

echo "uploading stemcell to director..."
bosh-go -n upload-stemcell ../stemcell/stemcell.tgz

echo "creating release..."
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
      name: ${stemcell_name}
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
      
  - name: manual-1
    type: manual
    subnets:
      - range:   ${network_no_dhcp_1_range}
        gateway: ${network_no_dhcp_1_gateway}
        dns:    [${dns}]
        static:  [${network_no_dhcp_1_ip}]
        cloud_properties:
          net_id: ${network_no_dhcp_1_id}
          security_groups: [${v3_e2e_security_group}]

  - name: manual-2
    type: manual
    subnets:
      - range:   ${network_no_dhcp_2_range}
        gateway: ${network_no_dhcp_2_gateway}
        dns:     [${dns}]
        static:  [${network_no_dhcp_2_ip}]
        cloud_properties:
          net_id: ${network_no_dhcp_2_id}
          security_groups: [${v3_e2e_security_group}]

jobs:
  - name: dummy
    template: dummy
    instances: 1
    resource_pool: default
    networks:
      - name : manual-1
        default: [dns, gateway]
        static_ips: [${network_no_dhcp_1_ip}]
      - name : manual-2
        static_ips: [${network_no_dhcp_2_ip}]

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
echo "checking network interfaces..."
echo "${v3_e2e_private_key_data}" > bosh.pem
chmod go-r bosh.pem
bosh-go ssh -d ${deployment_name} \
    --gw-host ${director_public_ip} \
    --gw-user vcap \
    --gw-private-key bosh.pem \
    dummy/0 \
    "PATH=/usr/sbin:/sbin ifconfig" > network_config

cat network_config | grep ${network_no_dhcp_1_ip} || failed_exit_code_1=$?
if [ $failed_exit_code_1 ]; then
    echo "failed to find network interface with ip: " ${network_no_dhcp_1_ip}
    exit 1
fi

cat network_config | grep ${network_no_dhcp_2_ip} || failed_exit_code_2=$?
if [ $failed_exit_code_2 ]; then
    echo "failed to find network interface with ip: " ${network_no_dhcp_2_ip}
    exit 1
fi

if [ "${delete_deployment_when_done}" = "true" ]; then
    bosh-go -n delete-deployment -d ${deployment_name}
    bosh-go -n clean-up --all
fi
