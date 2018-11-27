#!/usr/bin/env bash

set -e -x

source bosh-cpi-src-in/ci/tasks/utils.sh

: ${bosh_vcap_password:?}
: ${v3_e2e_flavor:?}
: ${v3_e2e_connection_timeout:?}
: ${v3_e2e_read_timeout:?}
: ${v3_e2e_state_timeout:?}
: ${v3_e2e_write_timeout:?}
: ${v3_e2e_bosh_registry_port:?}
: ${v3_e2e_api_key:?}
: ${v3_e2e_auth_url:?}
: ${v3_e2e_project:?}
: ${v3_e2e_domain:?}
: ${v3_e2e_username:?}
: ${v3_e2e_private_key_data:?}
: ${time_server_1:?}
: ${time_server_2:?}
: ${distro:?}
optional_value bosh_openstack_ca_cert

metadata=terraform/metadata

export_terraform_variable "dns"
export_terraform_variable "v3_e2e_default_key_name"
export_terraform_variable "director_public_ip"
export_terraform_variable "director_private_ip"
export_terraform_variable "v3_e2e_net_cidr"
export_terraform_variable "v3_e2e_net_gateway"
export_terraform_variable "v3_e2e_net_id"
export_terraform_variable "v3_e2e_security_group"

deployment_dir="${PWD}/upgrade-deployment"
dummy_deployment_input="${PWD}/dummy-deployment"
director_deployment_input="${PWD}/director-deployment"
manifest_filename="director-manifest.yml"
private_key=bosh.pem
bosh_vcap_password_hash=$(ruby -e 'require "securerandom";puts ENV["bosh_vcap_password"].crypt("$6$#{SecureRandom.base64(14)}")')

cp ${director_deployment_input}/director-manifest-state.json $deployment_dir
cp ${director_deployment_input}/director_ca $deployment_dir
cp ${director_deployment_input}/bosh.pem $deployment_dir
cp ${director_deployment_input}/credentials.yml $deployment_dir
cp ${director_deployment_input}/custom-ca.yml $deployment_dir

echo "setting up artifacts used in $manifest_filename"
cp ./bosh-cpi-release/*.tgz ${deployment_dir}/bosh-openstack-cpi.tgz
cp ./stemcell-director/*.tgz ${deployment_dir}/stemcell.tgz
prepare_bosh_release $distro

cd ${deployment_dir}

echo "${v3_e2e_private_key_data}" > ${private_key}
chmod go-r ${private_key}
eval $(ssh-agent)
ssh-add ${private_key}

export BOSH_ENVIRONMENT=${director_public_ip}
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=$(bosh-go int credentials.yml  --path /admin_password)
export BOSH_CA_CERT=director_ca

echo "check bosh deployment interpolation"
bosh-go int ../bosh-deployment/bosh.yml \
    --var-errs --var-errs-unused \
    --vars-store ./credentials.yml \
    --vars-file ./custom-ca.yml \
    -o ../bosh-deployment/misc/powerdns.yml \
    -o ../bosh-deployment/openstack/cpi.yml \
    -o ../bosh-deployment/external-ip-with-registry-not-recommended.yml \
    -o ../bosh-cpi-src-in/ci/ops_files/deployment-configuration.yml \
    -o ../bosh-cpi-src-in/ci/ops_files/custom-manual-networking.yml \
    -o ../bosh-cpi-src-in/ci/ops_files/timeouts.yml \
    -o ../bosh-cpi-src-in/ci/ops_files/ntp.yml \
    -v auth_url=${v3_e2e_auth_url} \
    -v availability_zone=${availability_zone:-'~'} \
    -v bosh_vcap_password_hash=${bosh_vcap_password_hash} \
    -v default_security_groups=[${v3_e2e_security_group}] \
    -v default_key_name=${v3_e2e_default_key_name} \
    -v director_name='bosh' \
    -v dns=${dns} \
    -v internal_ip=${director_private_ip} \
    -v external_ip=${director_public_ip} \
    -v primary_net_id=${v3_e2e_net_id} \
    -v internal_cidr=${v3_e2e_net_cidr} \
    -v internal_gw=${v3_e2e_net_gateway} \
    -v openstack_connection_timeout=${v3_e2e_connection_timeout} \
    -v openstack_project=${v3_e2e_project} \
    -v openstack_domain=${v3_e2e_domain} \
    -v openstack_flavor=${v3_e2e_flavor} \
    -v openstack_password=${v3_e2e_api_key} \
    -v openstack_read_timeout=${v3_e2e_read_timeout} \
    -v openstack_state_timeout=${v3_e2e_state_timeout} \
    -v openstack_username=${v3_e2e_username} \
    -v openstack_write_timeout=${v3_e2e_write_timeout} \
    --var-file=private_key=${private_key} \
    -v region=null \
    -v time_server_1=${time_server_1} \
    -v time_server_2=${time_server_2} | tee ${manifest_filename}

echo "upgrading existing BOSH Director VM..."
bosh-go create-env ${manifest_filename} \
    --vars-file credentials.yml \
    --state director-manifest-state.json

echo "recreating existing dummy deployment..."
bosh-go -n deploy --recreate -d dummy ${dummy_deployment_input}/dummy-manifest.yml

echo "deleting dummy deployment..."
bosh-go -n delete-deployment -d dummy

echo "cleaning up director..."
bosh-go -n clean-up --all
