#!/usr/bin/env bash

set -e

source bosh-cpi-src-in/ci/tasks/utils.sh

: ${bosh_admin_password:?}
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
: ${distro:?}
optional_value bosh_openstack_ca_cert
optional_value availability_zone

cp terraform-bats-manual/metadata terraform-bats-manual-deploy
metadata=terraform-bats-manual/metadata

export_terraform_variable "key_name"
export_terraform_variable "openstack_project"
export_terraform_variable "dns"
export_terraform_variable "director_private_ip"
export_terraform_variable "primary_net_gateway"
export_terraform_variable "primary_net_cidr"
export_terraform_variable "director_public_ip"
export_terraform_variable "primary_net_id"
export_terraform_variable "security_group"

semver=`cat version-semver/number`
cpi_release_name="bosh-openstack-cpi"
deployment_dir="${PWD}/bosh-director-deployment"
manifest_filename="bosh"
private_key=bats.pem
bosh_vcap_password_hash=$(ruby -e 'require "securerandom";puts ENV["bosh_admin_password"].crypt("$6$#{SecureRandom.base64(14)}")')

echo "setting up artifacts used in ${manifest_filename}.yml"
cp ./bosh-cpi-dev-artifacts/${cpi_release_name}-${semver}.tgz ${deployment_dir}/${cpi_release_name}.tgz
cp ./stemcell/stemcell.tgz ${deployment_dir}/stemcell.tgz
prepare_bosh_release

echo "Calculating MD5 of original stemcell:"
echo $(md5sum stemcell/stemcell.tgz)

cd ${deployment_dir}

echo "Calculating MD5 of copied stemcell:"
echo $(md5sum stemcell.tgz)

echo "${private_key_data}" > ${private_key}
chmod go-r ${private_key}
eval $(ssh-agent)
ssh-add ${private_key}

cat > "${manifest_filename}-template.yml" <<EOF
---
name: bosh

releases:
  - name: bosh
    url: file://bosh-release.tgz
  - name: ${cpi_release_name}
    url: file://${cpi_release_name}.tgz

networks:
  - name: private
    type: manual
    subnets:
      - range:   ${primary_net_cidr}
        gateway: ${primary_net_gateway}
        dns:     [${dns}]
        static:  [${director_private_ip}]
        cloud_properties:
          net_id: ${primary_net_id}
          security_groups: [${security_group}]
  - name: public
    type: vip

resource_pools:
  - name: default
    network: private
    stemcell:
      url: file://stemcell.tgz
    cloud_properties:
      instance_type: ${openstack_flavor}
      availability_zone: ${availability_zone:-"~"}
    env:
      bosh:
        password: ${bosh_vcap_password_hash}

disk_pools:
  - name: default
    disk_size: 25_000

jobs:
  - name: bosh
    templates:
      - {name: nats, release: bosh}
      - {name: postgres-9.4, release: bosh}
      - {name: blobstore, release: bosh}
      - {name: director, release: bosh}
      - {name: health_monitor, release: bosh}
      - {name: registry, release: bosh}
      - {name: powerdns, release: bosh}
      - {name: openstack_cpi, release: ${cpi_release_name}}

    instances: 1
    resource_pool: default
    persistent_disk_pool: default

    networks:
      - name: private
        static_ips: [${director_private_ip}]
        default: [dns, gateway]
      - name: public
        static_ips: [${director_public_ip}]

    properties:
      nats:
        address: 127.0.0.1
        user: nats
        password: ${bosh_admin_password}

      postgres-9.4: &db
        host: 127.0.0.1
        user: postgres
        password: ${bosh_admin_password}
        database: bosh
        adapter: postgres

      # Tells the Director/agents how to contact registry
      registry:
        address: ${director_private_ip}
        host: ${director_private_ip}
        db: *db
        http: {user: admin, password: ${bosh_admin_password}, port: ${bosh_registry_port}}
        username: admin
        password: ${bosh_admin_password}
        port: ${bosh_registry_port}

      # Tells the Director/agents how to contact blobstore
      blobstore:
        address: ${director_private_ip}
        port: 25250
        provider: dav
        director: {user: director, password: ${bosh_admin_password}}
        agent: {user: agent, password: ${bosh_admin_password}}

      director:
        address: 127.0.0.1
        name: micro
        db: *db
        cpi_job: openstack_cpi
        debug:
          keep_unreachable_vms: ${DEBUG_BATS}
        user_management:
          provider: local
          local:
            users:
              - {name: admin, password: ${bosh_admin_password}}
        ssl:
          key: ((director_ssl.private_key))
          cert: ((director_ssl.certificate))

      hm:
        http: {user: hm, password: ${bosh_admin_password}}
        director_account: {user: admin, password: ${bosh_admin_password}, ca_cert: ((default_ca.ca))}

      dns:
        address: 127.0.0.1
        db: *db

      openstack: &openstack
        auth_url: ${openstack_auth_url}
        username: ${openstack_username}
        api_key: ${openstack_api_key}
        project: ${openstack_project}
        domain: ${openstack_domain}
        region: #leave this blank
        endpoint_type: publicURL
        default_key_name: ${key_name}
        default_security_groups:
          - ${security_group}
        state_timeout: ${openstack_state_timeout}
        wait_resource_poll_interval: 5
        connection_options:
          connect_timeout: ${openstack_connection_timeout}
          read_timeout: ${openstack_read_timeout}
          write_timeout: ${openstack_write_timeout}
          ca_cert: ((openstack_ca_cert))

      # Tells agents how to contact nats
      agent: {mbus: "nats://nats:${bosh_admin_password}@${director_private_ip}:4222"}

      ntp: &ntp
        - ${time_server_1}
        - ${time_server_2}

cloud_provider:
  template: {name: openstack_cpi, release: ${cpi_release_name}}

  # Tells bosh-micro how to SSH into deployed VM
  ssh_tunnel:
    host: ${director_public_ip}
    port: 22
    user: vcap
    private_key: ${private_key}

  # Tells bosh-micro how to contact remote agent
  mbus: https://mbus-user:${bosh_admin_password}@${director_public_ip}:6868

  properties:
    openstack: *openstack

    # Tells CPI how agent should listen for requests
    agent: {mbus: "https://mbus-user:${bosh_admin_password}@0.0.0.0:6868"}

    blobstore:
      provider: local
      path: /var/vcap/micro_bosh/data/cache

    ntp: *ntp

variables:
- name: default_ca
  type: certificate
- name: director_ssl
  type: certificate
  options:
    ca: default_ca
    common_name: ${director_public_ip}
    alternative_names: [${director_public_ip}]
EOF

echo -e "${director_ca}" > director_ca
echo -e "${director_ca_private_key}" > director_ca_private_key
echo -e "${bosh_openstack_ca_cert}" > bosh_openstack_ca_cert
../bosh-cpi-src-in/ci/ruby_scripts/render_credentials > credentials.yml

echo "using bosh CLI version..."
bosh-go --version

echo "validating manifest and variables..."
bosh-go int ${manifest_filename}-template.yml \
    --var-errs \
    --var-errs-unused \
    --vars-store credentials.yml > ${manifest_filename}.yml

cat ${manifest_filename}.yml

echo "deploying BOSH..."
bosh-go create-env ${manifest_filename}-template.yml \
    --vars-store credentials.yml \
    --state bosh-state.json