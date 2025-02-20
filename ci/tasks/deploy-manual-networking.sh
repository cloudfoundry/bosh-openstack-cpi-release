#!/usr/bin/env bash

set -ex

source bosh-openstack-cpi-release/ci/tasks/utils.sh

# Variables from pipeline.yml
: ${openstack_flavor:?}
: ${openstack_connection_timeout:?}
: ${openstack_read_timeout:?}
: ${openstack_write_timeout:?}
: ${openstack_state_timeout:?}
: ${openstack_auth_url:?}
: ${openstack_username:?}
: ${openstack_api_key:?}
: ${openstack_domain:?}
: ${openstack_ca_file_path:?}
: ${DEBUG_BATS:?}
: ${distro:?}
optional_value availability_zone

# Variables from TF
export_terraform_variable terraform-cpi/metadata "default_key_name"
export_terraform_variable terraform-cpi/metadata "openstack_project"
export_terraform_variable terraform-cpi/metadata "director_private_ip"
export_terraform_variable terraform-cpi/metadata "primary_net_gateway"
export_terraform_variable terraform-cpi/metadata "primary_net_cidr"
export_terraform_variable terraform-cpi/metadata "security_group"

export_terraform_variable terraform-cpi/metadata "openstack_project"
export_terraform_variable terraform-cpi/metadata "primary_net_id"
export_terraform_variable terraform-cpi/metadata "dns"
export_terraform_variable terraform-cpi/metadata "director_public_ip"

cpi_release_name="bosh-openstack-cpi"
deployment_dir="${PWD}/bosh-director-deployment"

maybe_use_custom_ca_ops_file=""
maybe_load_custom_ca_file=""

case "$openstack_ca_file_path" in
    "")
        break
        ;;
    *)
        maybe_use_custom_ca_ops_file="-o ../bosh-deployment/openstack/custom-ca.yml"
        maybe_load_custom_ca_file="--var-file=openstack_ca_cert=${openstack_ca_file_path}"
        ;;
esac

echo "setting up artifacts used in bosh.yml"
pushd bosh-openstack-cpi-release
    bosh-go -n create-release \
    --name "bosh-openstack-cpi" \
    --tarball "../bosh-openstack-cpi-dev.tgz"

popd
cp ./bosh-openstack-cpi-dev.tgz ${deployment_dir}/${cpi_release_name}.tgz
cp ./stemcell-director/*.tgz ${deployment_dir}/stemcell.tgz
prepare_bosh_release ${distro}

echo "Calculating MD5 of original stemcell:"
echo $(md5sum stemcell-director/*.tgz)
echo "Calculating MD5 of copied stemcell:"
echo $(md5sum ${deployment_dir}/stemcell.tgz)

cd ${deployment_dir}

echo "using bosh CLI version..."
bosh-go --version

echo "check bosh deployment interpolation"
bosh-go int ../bosh-deployment/bosh.yml \
    --var-errs --var-errs-unused \
    --vars-store ./credentials.yml \
    -o ../bosh-deployment/openstack/cpi.yml \
    ${maybe_use_custom_ca_ops_file} \
    -o ../bosh-deployment/external-ip-not-recommended.yml \
    -o ../bosh-deployment/misc/source-releases/bosh.yml \
    -o ../bosh-deployment/jumpbox-user.yml \
    -o ../bosh-openstack-cpi-release/ci/ops_files/deployment-configuration.yml \
    -o ../bosh-openstack-cpi-release/ci/ops_files/custom-manual-networking.yml \
    -o ../bosh-openstack-cpi-release/ci/ops_files/timeouts.yml \
    -o ../bosh-openstack-cpi-release/ci/ops_files/remove-registry.yml \
    -o ../bosh-openstack-cpi-release/ci/ops_files/move-agent-properties-to-env-for-create-env.yml \
    -v auth_url=${openstack_auth_url} \
    -v availability_zone=${availability_zone:-'~'} \
    -v default_security_groups=[${security_group}] \
    -v default_key_name=${default_key_name} \
    -v director_name='bosh' \
    -v dns=${dns} \
    -v internal_ip=${director_private_ip} \
    -v external_ip=${director_public_ip} \
    -v primary_net_id=${primary_net_id} \
    -v internal_cidr=${primary_net_cidr} \
    -v internal_gw=${primary_net_gateway} \
    -v openstack_connection_timeout=${openstack_connection_timeout} \
    -v openstack_project=${openstack_project} \
    -v openstack_domain=${openstack_domain} \
    -v openstack_flavor=${openstack_flavor} \
    -v openstack_password=${openstack_api_key} \
    -v openstack_read_timeout=${openstack_read_timeout} \
    -v openstack_state_timeout=${openstack_state_timeout} \
    -v openstack_username=${openstack_username} \
    -v openstack_write_timeout=${openstack_write_timeout} \
    ${maybe_load_custom_ca_file} \
    -v region=null | tee bosh.yml

echo "deploying BOSH..."
bosh-go create-env bosh.yml \
    --vars-store credentials.yml \
    --state bosh-state.json
