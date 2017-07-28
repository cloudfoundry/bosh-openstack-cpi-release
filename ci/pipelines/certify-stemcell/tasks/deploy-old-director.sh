#!/usr/bin/env bash

set -e -x

source bosh-cpi-src-in/ci/tasks/utils.sh

: ${bosh_vcap_password:?}
: ${v3_e2e_private_key_data:?}
: ${old_bosh_release_version:?}
: ${old_bosh_release_sha1:?}
: ${director_ca:?}
: ${director_ca_private_key:?}
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
: ${time_server_1:?}
: ${time_server_2:?}
: ${old_openstack_cpi_release_version:?}
: ${old_openstack_cpi_release_sha1:?}
: ${old_bosh_stemcell_sha1:?}
: ${old_bosh_stemcell_name:?}
: ${old_bosh_stemcell_version:?}
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

deployment_dir="${PWD}/director-deployment"
manifest_template_filename="director-manifest-template.yml"
manifest_filename="director-manifest.yml"
export private_key=bosh.pem
export bosh_vcap_password_hash=$(ruby -e 'require "securerandom";puts ENV["bosh_vcap_password"].crypt("$6$#{SecureRandom.base64(14)}")')

echo "setting up artifacts used in $manifest_filename"
prepare_bosh_release $distro $old_bosh_release_version $old_bosh_stemcell_version
export bosh_release_tgz=${deployment_dir}/bosh-release.tgz

cd ${deployment_dir}

echo "${v3_e2e_private_key_data}" > ${private_key}
chmod go-r ${private_key}
eval $(ssh-agent)
ssh-add ${private_key}

echo -e "${director_ca}" > director_ca
echo -e "${director_ca_private_key}" > director_ca_private_key
echo -e "${bosh_openstack_ca_cert}" > bosh_openstack_ca_cert
../bosh-cpi-src-in/ci/ruby_scripts/render_credentials > custom-ca.yml

echo "using bosh CLI version..."
bosh-go --version

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
    -o ../bosh-cpi-src-in/ci/ops_files/custom-powerdns.yml \
    -o ../bosh-cpi-src-in/ci/ops_files/custom-bosh-release.yml \
    -o ../bosh-cpi-src-in/ci/ops_files/custom-redis-release.yml \
    -v auth_url=${v3_e2e_auth_url} \
    -v availability_zone=${availability_zone:-'~'} \
    -v bosh_vcap_password_hash=${bosh_vcap_password_hash} \
    -v default_security_groups=[${v3_e2e_security_group}] \
    -v default_key_name=${v3_e2e_default_key_name} \
    -v director_name='bosh' \
    -v dns="[${dns}]" \
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
    -v bosh_release_tgz=${bosh_release_tgz} \
    -v old_openstack_cpi_release_version=${old_openstack_cpi_release_version} \
    -v old_openstack_cpi_release_sha1=${old_openstack_cpi_release_sha1} \
    -v old_bosh_stemcell_sha1=${old_bosh_stemcell_sha1} \
    -v old_bosh_stemcell_name=${old_bosh_stemcell_name} \
    -v old_bosh_stemcell_version=${old_bosh_stemcell_version} \
    --var-file=private_key=${private_key} \
    -v region=null \
    -v time_server_1=${time_server_1} \
    -v time_server_2=${time_server_2} | tee old-director-manifest.yml


echo "deploying BOSH..."
bosh-go create-env old-director-manifest.yml \
    --vars-store credentials.yml \
    --state director-manifest-state.json
