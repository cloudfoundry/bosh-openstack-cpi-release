#!/usr/bin/env bash

set -e

source bosh-cpi-src-in/ci/tasks/utils.sh

: ${v3_e2e_private_key_data:?}
: ${director_ca:?}
: ${director_ca_private_key:?}
: ${distro:?}

optional_value bosh_openstack_ca_cert

metadata=terraform/metadata

export_terraform_variable "v3_e2e_default_key_name" "ci_"
export_terraform_variable "director_public_ip" "ci_"
export_terraform_variable "director_private_ip" "ci_"
export_terraform_variable "v3_e2e_net_cidr" "ci_"
export_terraform_variable "v3_e2e_net_gateway" "ci_"
export_terraform_variable "v3_e2e_net_id" "ci_"
export_terraform_variable "v3_e2e_security_group" "ci_"
export_terraform_variable "dns" "ci_"

export BOSH_INIT_LOG_LEVEL=DEBUG

deployment_dir="${PWD}/deployment"
manifest_filename="e2e-director-manifest.yml"
export ci_private_key=${deployment_dir}/e2e.pem
export ci_bosh_vcap_password_hash=$(ruby -e 'require "securerandom";puts ENV["ci_bosh_admin_password"].crypt("$6$#{SecureRandom.base64(14)}")')

echo "setting up artifacts used in $manifest_filename"
cp ./bosh-cpi-release/*.tgz ${deployment_dir}/bosh-openstack-cpi.tgz
cp ./stemcell/stemcell.tgz ${deployment_dir}/stemcell.tgz
prepare_bosh_release
export ci_bosh_release_tgz=${deployment_dir}/bosh-release.tgz
export ci_bosh_openstack_cpi_release_tgz=${deployment_dir}/bosh-openstack-cpi.tgz
export ci_stemcell_tgz=${deployment_dir}/stemcell.tgz

echo "${v3_e2e_private_key_data}" > ${ci_private_key}
chmod go-r ${ci_private_key}
eval $(ssh-agent)
ssh-add ${ci_private_key}

echo -e "${director_ca}" > director_ca
echo -e "${director_ca_private_key}" > director_ca_private_key
echo -e "${bosh_openstack_ca_cert}" > bosh_openstack_ca_cert
./bosh-cpi-src-in/ci/ruby_scripts/render_credentials > ${deployment_dir}/credentials.yml

cd ${deployment_dir}

echo "using bosh CLI version..."
bosh-go --version

echo "validating manifest and variables..."
bosh-go int ../bosh-cpi-src-in/ci/pipelines/certify-stemcell/assets/director-manifest-template.yml \
    -o ../bosh-cpi-src-in/ci/pipelines/certify-stemcell/assets/default-director-delta.yml \
    --var-errs \
    --var-errs-unused \
    --vars-env=ci \
    --vars-store credentials.yml

echo "deploying BOSH..."
bosh-go create-env ../bosh-cpi-src-in/ci/pipelines/certify-stemcell/assets/director-manifest-template.yml \
    -o ../bosh-cpi-src-in/ci/pipelines/certify-stemcell/assets/default-director-delta.yml \
    --vars-env=ci \
    --vars-store credentials.yml \
    --state director-manifest-state.json
