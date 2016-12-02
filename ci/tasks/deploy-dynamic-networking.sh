#!/usr/bin/env bash

set -e

source bosh-cpi-src-in/ci/tasks/utils.sh

: {bosh_admin_password:?}
: {openstack_flavor:?}
: {openstack_connection_timeout:?}
: {openstack_read_timeout:?}
: {openstack_write_timeout:?}
: {openstack_state_timeout:?}
: {private_key_data:?}
: {bosh_registry_port:?}
: {openstack_auth_url:?}
: {openstack_username:?}
: {openstack_api_key:?}
: {openstack_domain:?}
: {time_server_1:?}
: {time_server_2:?}
optional_value bosh_openstack_ca_cert
optional_value distro

source /etc/profile.d/chruby-with-ruby-2.1.2.sh

cp terraform-bats-dynamic/metadata terraform-bats-dynamic-deploy
metadata=terraform-bats-dynamic/metadata

export_terraform_variable "key_name"
export_terraform_variable "openstack_project"
export_terraform_variable "director_public_ip"
export_terraform_variable "primary_net_id"
export_terraform_variable "dns"
export_terraform_variable "security_group"

export BOSH_INIT_LOG_LEVEL=DEBUG

semver=`cat version-semver/number`
cpi_release_name="bosh-openstack-cpi"
deployment_dir="${PWD}/bosh-director-deployment"
manifest_filename="bosh.yml"
private_key=${deployment_dir}/bats.pem
bosh_vcap_password_hash=$(ruby -e 'require "securerandom";puts ENV["bosh_admin_password"].crypt("$6$#{SecureRandom.base64(14)}")')

echo "setting up artifacts used in $manifest_filename"
cp ./bosh-cpi-dev-artifacts/${cpi_release_name}-${semver}.tgz ${deployment_dir}/${cpi_release_name}.tgz
cp ./stemcell/stemcell.tgz ${deployment_dir}/stemcell.tgz
prepare_bosh_release

echo "Calculating MD5 of original stemcell:"
echo $(md5sum stemcell/stemcell.tgz)

echo "Calculating MD5 of copied stemcell:"
echo $(md5sum ${deployment_dir}/stemcell.tgz)

echo "${private_key_data}" > ${private_key}
chmod go-r ${private_key}
eval $(ssh-agent)
ssh-add ${private_key}

cat > "${deployment_dir}/${manifest_filename}" <<EOF
---
name: bosh

releases:
  - name: bosh
    url: file://bosh-release.tgz
  - name: ${cpi_release_name}
    url: file://${cpi_release_name}.tgz

networks:
  - name: private
    type: dynamic
    dns: [${dns}]
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
        address: ${director_public_ip}
        host: ${director_public_ip}
        db: *db
        http: {user: admin, password: ${bosh_admin_password}, port: ${bosh_registry_port}}
        username: admin
        password: ${bosh_admin_password}
        port: ${bosh_registry_port}
        endpoint: http://admin:${bosh_admin_password}@${director_public_ip}:${bosh_registry_port}

      # Tells the Director/agents how to contact blobstore
      blobstore:
        address: ${director_public_ip}
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

      hm:
        http: {user: hm, password: ${bosh_admin_password}}
        director_account: {user: admin, password: ${bosh_admin_password}}

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
        human_readable_vm_names: true
        connection_options:
          connect_timeout: ${openstack_connection_timeout}
          read_timeout: ${openstack_read_timeout}
          write_timeout: ${openstack_write_timeout}
          ca_cert: $(if [ -z "$bosh_openstack_ca_cert" ]; then echo "~"; else echo "\"$(echo ${bosh_openstack_ca_cert} | sed -r  -e 's/ /\\n/g ' -e 's/\\nCERTIFICATE-----/ CERTIFICATE-----/g')\""; fi)

      # Tells agents how to contact nats
      agent: {mbus: "nats://nats:${bosh_admin_password}@${director_public_ip}:4222"}

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
    private_key: bats.pem

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
EOF

echo "using bosh CLI version..."
bosh version

echo "targeting bosh director at ${director_public_ip}"
bosh -n target ${director_public_ip} || failed_exit_code=$?
if [ -z "$failed_exit_code" ]; then
  bosh login admin ${bosh_admin_password}
  echo "cleanup director (especially orphan disks)"
  bosh -n cleanup --all
fi

initver=$(cat bosh-init/version)
bosh_init="${PWD}/bosh-init/bosh-init-${initver}-linux-amd64"
chmod +x $bosh_init

echo "deploying BOSH..."
$bosh_init deploy ${deployment_dir}/${manifest_filename}
