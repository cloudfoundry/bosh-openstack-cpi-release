#!/usr/bin/env bash

set -e

source bosh-cpi-src-in/ci/tasks/utils.sh

: ${bosh_admin_password:?}
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
: ${v3_e2e_blobstore_bucket:?}
: ${v3_e2e_blobstore_host:?}
: ${v3_e2e_blobstore_access_key:?}
: ${v3_e2e_blobstore_secret_key:?}
: ${time_server_1:?}
: ${time_server_2:?}
: ${director_ca:?}
: ${director_ca_private_key:?}
: ${distro:?}
optional_value bosh_openstack_ca_cert
optional_value v3_e2e_use_dhcp
optional_value v3_e2e_config_drive

metadata=terraform/metadata

export_terraform_variable "v3_e2e_default_key_name"
export_terraform_variable "director_public_ip"
export_terraform_variable "director_private_ip"
export_terraform_variable "v3_e2e_net_cidr"
export_terraform_variable "v3_e2e_net_gateway"
export_terraform_variable "v3_e2e_net_id"
export_terraform_variable "v3_e2e_security_group"
export_terraform_variable "dns"

export BOSH_INIT_LOG_LEVEL=DEBUG

deployment_dir="${PWD}/director-deployment"
manifest_filename="e2e-director-manifest"
private_key=e2e.pem
bosh_vcap_password_hash=$(ruby -e 'require "securerandom";puts ENV["bosh_admin_password"].crypt("$6$#{SecureRandom.base64(14)}")')

echo "setting up artifacts used in ${manifest_filename}-template.yml"
cp ./bosh-cpi-release/*.tgz ${deployment_dir}/bosh-openstack-cpi.tgz
cp ./stemcell/stemcell.tgz ${deployment_dir}/stemcell.tgz
prepare_bosh_release

cd ${deployment_dir}

echo "${v3_e2e_private_key_data}" > ${private_key}
chmod go-r ${private_key}
eval $(ssh-agent)
ssh-add ${private_key}

cat > "${manifest_filename}-template.yml"<<EOF
---
name: bosh

releases:
  - name: bosh
    url: file://bosh-release.tgz
  - name: bosh-openstack-cpi
    url: file://bosh-openstack-cpi.tgz

networks:
  - name: private
    type: manual
    subnets:
      - range:    ${v3_e2e_net_cidr}
        gateway:  ${v3_e2e_net_gateway}
        dns:     [${dns}]
        static:  [${director_private_ip}]
        cloud_properties:
          net_id: ${v3_e2e_net_id}
          security_groups: [${v3_e2e_security_group}]
  - name: public
    type: vip

resource_pools:
  - name: default
    network: private
    stemcell:
      url: file://stemcell.tgz
    cloud_properties:
      instance_type: ${v3_e2e_flavor}
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
      - {name: postgres, release: bosh}
      - {name: director, release: bosh}
      - {name: health_monitor, release: bosh}
      - {name: powerdns, release: bosh}
      - {name: registry, release: bosh}
      - {name: openstack_cpi, release: bosh-openstack-cpi}

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

      postgres: &db
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
        http: {user: admin, password: ${bosh_admin_password}, port: ${v3_e2e_bosh_registry_port}}
        username: admin
        password: ${bosh_admin_password}
        port: ${v3_e2e_bosh_registry_port}

      # Tells the Director/agents how to contact blobstore
      blobstore:
        provider: s3
        access_key_id: ${v3_e2e_blobstore_access_key}
        secret_access_key: ${v3_e2e_blobstore_secret_key}
        bucket_name: ${v3_e2e_blobstore_bucket}
        host: ${v3_e2e_blobstore_host}

      director:
        address: 127.0.0.1
        name: micro
        db: *db
        cpi_job: openstack_cpi
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
        auth_url: ${v3_e2e_auth_url}
        username: ${v3_e2e_username}
        api_key:  ${v3_e2e_api_key}
        project:  ${v3_e2e_project}
        domain:   ${v3_e2e_domain}
        region: #leave this blank
        endpoint_type: publicURL
        config_drive: ${v3_e2e_config_drive}
        use_dhcp: ${v3_e2e_use_dhcp}
        default_key_name: ${v3_e2e_default_key_name}
        default_security_groups:
          - ${v3_e2e_security_group}
        state_timeout: ${v3_e2e_state_timeout}
        wait_resource_poll_interval: 5
        connection_options:
          connect_timeout: ${v3_e2e_connection_timeout}
          read_timeout: ${v3_e2e_read_timeout}
          write_timeout: ${v3_e2e_write_timeout}
          ca_cert: ((openstack_ca_cert))

      # Tells agents how to contact nats
      agent: {mbus: "nats://nats:${bosh_admin_password}@${director_private_ip}:4222"}

      ntp: &ntp
        - ${time_server_1}
        - ${time_server_2}

cloud_provider:
  template: {name: openstack_cpi, release: bosh-openstack-cpi}

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
    --state ${manifest_filename}-state.json
