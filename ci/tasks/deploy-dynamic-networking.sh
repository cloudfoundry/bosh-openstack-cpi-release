#!/usr/bin/env bash

set -e

source bosh-cpi-src-in/ci/tasks/utils.sh

# Variables from pipeline.yml
: ${bosh_vcap_password:?}
: ${director_ca:?}
: ${director_ca_private_key:?}
: ${openstack_flavor:?}
: ${openstack_connection_timeout:?}
: ${openstack_read_timeout:?}
: ${openstack_write_timeout:?}
: ${openstack_state_timeout:?}
: ${private_key_data:?}
: ${bosh_registry_port:?}
: ${openstack_auth_url:?}
: ${openstack_username:?}
: ${openstack_api_key:?}
: ${openstack_domain:?}
: ${time_server_1:?}
: ${time_server_2:?}
: ${DEBUG_BATS:?}
optional_value bosh_openstack_ca_cert
optional_value availability_zone

cp terraform-bats-dynamic/metadata terraform-bats-dynamic-deploy
metadata=terraform-bats-dynamic/metadata

# Variables from TF
export_terraform_variable "key_name"
export_terraform_variable "openstack_project"
export_terraform_variable "security_group"
export_terraform_variable "director_public_ip"
export_terraform_variable "openstack_project"
export_terraform_variable "primary_net_id"
export_terraform_variable "dns"


semver=`cat version-semver/number`
cpi_release_name="bosh-openstack-cpi"
deployment_dir="${PWD}/bosh-director-deployment"
bosh_vcap_password_hash=$(ruby -rsecurerandom -e 'puts ENV["bosh_vcap_password"].crypt("$6$#{SecureRandom.base64(14)}")')
private_ssh_key_file="bats.key"

echo "setting up artifacts used in bosh.yml"
cp ./bosh-cpi-dev-artifacts/${cpi_release_name}-${semver}.tgz ${deployment_dir}/${cpi_release_name}.tgz
cp ./stemcell/stemcell.tgz ${deployment_dir}/stemcell.tgz
prepare_bosh_release

echo "Calculating MD5 of original stemcell:"
echo $(md5sum stemcell/stemcell.tgz)
echo "Calculating MD5 of copied stemcell:"
echo $(md5sum ${deployment_dir}/stemcell.tgz)

cd ${deployment_dir}
echo "${private_key_data}" > ${private_ssh_key_file}
# For using key directly while debugging
chmod 0600 ${private_ssh_key_file}

# Variables from pre-seeded vars store
echo -e "${bosh_openstack_ca_cert}" > bosh_openstack_ca_cert
echo -e "${director_ca}" > director_ca
echo -e "${director_ca_private_key}" > director_ca_private_key
../bosh-cpi-src-in/ci/ruby_scripts/render_credentials > ./custom-ca.yml

echo "using bosh CLI version..."
bosh-go --version

echo "check bosh deployment interpolation"
bosh-go int ../bosh-deployment/bosh.yml \
    --var-errs --var-errs-unused \
    --vars-env tf \
    --vars-file ./custom-ca.yml \
    --vars-store ./credentials.yml \
    -o ../bosh-deployment/powerdns.yml \
    -o ../bosh-deployment/openstack/cpi.yml \
    -o ../bosh-deployment/external-ip-with-registry-not-recommended.yml \
    -o ../bosh-cpi-src-in/ci/ops_files/deployment-configuration.yml \
    -o ../bosh-cpi-src-in/ci/ops_files/custom-dynamic-networking.yml \
    -o ../bosh-cpi-src-in/ci/ops_files/timeouts.yml \
    -o ../bosh-cpi-src-in/ci/ops_files/ntp.yml \
    -o ../bosh-cpi-src-in/ci/ops_files/custom-powerdns.yml \
    -v auth_url=${openstack_auth_url} \
    -v availability_zone=${availability_zone:-'~'} \
    -v bosh_vcap_password_hash=${bosh_vcap_password_hash} \
    -v default_security_groups=[${security_group}] \
    -v default_key_name=${key_name} \
    -v director_name='bosh' \
    -v dns=${dns} \
    -v dns_recursor_ip=${dns} \
    -v internal_ip=${director_public_ip} \
    -v external_ip=${director_public_ip} \
    -v primary_net_id=${primary_net_id} \
    -v openstack_connection_timeout=${openstack_connection_timeout} \
    -v openstack_project=${openstack_project} \
    -v openstack_domain=${openstack_domain} \
    -v openstack_flavor=${openstack_flavor} \
    -v openstack_password=${openstack_api_key} \
    -v openstack_read_timeout=${openstack_read_timeout} \
    -v openstack_state_timeout=${openstack_state_timeout} \
    -v openstack_username=${openstack_username} \
    -v openstack_write_timeout=${openstack_write_timeout} \
    --var-file=private_key=${private_ssh_key_file} \
    -v region=null \
    -v time_server_1=${time_server_1} \
    -v time_server_2=${time_server_2} | tee bosh.yml

echo "deploying BOSH..."
bosh-go create-env bosh.yml \
    --vars-store credentials.yml \
    --state bosh-state.json
