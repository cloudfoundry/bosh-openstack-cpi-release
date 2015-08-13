#!/usr/bin/env bash

set -e

source bosh-cpi-release/ci/tasks/utils.sh

ensure_not_replace_value base_os
ensure_not_replace_value network_type_to_test
ensure_not_replace_value openstack_flavor
ensure_not_replace_value openstack_connection_timeout
ensure_not_replace_value openstack_read_timeout
ensure_not_replace_value openstack_write_timeout
ensure_not_replace_value openstack_state_timeout
ensure_not_replace_value private_key_data
ensure_not_replace_value bosh_registry_port
ensure_not_replace_value openstack_net_id
ensure_not_replace_value openstack_security_group
ensure_not_replace_value openstack_default_key_name
ensure_not_replace_value openstack_auth_url
ensure_not_replace_value openstack_username
ensure_not_replace_value openstack_api_key
ensure_not_replace_value openstack_tenant
ensure_not_replace_value openstack_floating_ip

source /etc/profile.d/chruby-with-ruby-2.1.2.sh

export BOSH_INIT_LOG_LEVEL=DEBUG

semver=`cat version-semver/number`
cpi_release_name="bosh-openstack-cpi"
working_dir=$PWD

mkdir -p $working_dir/keys
echo "$private_key_data" > $working_dir/keys/bats.pem

manifest_dir="${working_dir}/director-state-file"
manifest_filename=${base_os}-${network_type_to_test}-director-manifest.yml

eval $(ssh-agent)
chmod go-r $working_dir/keys/bats.pem
ssh-add $working_dir/keys/bats.pem

cat > "${manifest_dir}/${manifest_filename}" <<EOF
---
name: bosh

releases:
  - name: bosh
    url: file://${working_dir}/bosh-release/release.tgz
  - name: ${cpi_release_name}
    url: file://${working_dir}/bosh-cpi-dev-artifacts/${cpi_release_name}-${semver}.tgz

networks:
- name: private
  type: dynamic
  dns:     [8.8.8.8]
  cloud_properties:
    net_id: ${openstack_net_id}
    security_groups: [${openstack_security_group}]
- name: public
  type: vip

resource_pools:
- name: default
  network: private
  stemcell:
    url: file://${working_dir}/stemcell/stemcell.tgz
  cloud_properties:
    instance_type: $openstack_flavor

disk_pools:
- name: default
  disk_size: 25_000

jobs:
- name: bosh
  templates:
  - {name: nats, release: bosh}
  - {name: redis, release: bosh}
  - {name: postgres, release: bosh}
  - {name: blobstore, release: bosh}
  - {name: director, release: bosh}
  - {name: health_monitor, release: bosh}
  - {name: registry, release: bosh}
  - {name: cpi, release: ${cpi_release_name}}

  instances: 1
  resource_pool: default
  persistent_disk_pool: default

  networks:
  - name: private
    default: [dns, gateway]
  - name: public
    static_ips: [${openstack_floating_ip}]

  properties:
    nats:
      address: 127.0.0.1
      user: nats
      password: nats-password

    redis:
      listen_addresss: 127.0.0.1
      address: 127.0.0.1
      password: redis-password

    postgres: &db
      host: 127.0.0.1
      user: postgres
      password: postgres-password
      database: bosh
      adapter: postgres

    # Tells the Director/agents how to contact registry
    registry:
      address: ${openstack_floating_ip}
      host: ${openstack_floating_ip}
      db: *db
      http: {user: admin, password: admin, port: ${bosh_registry_port}}
      username: admin
      password: admin
      port: ${bosh_registry_port}
      endpoint: http://admin:admin@${openstack_floating_ip}:${bosh_registry_port}

    # Tells the Director/agents how to contact blobstore
    blobstore:
      address: ${openstack_floating_ip}
      port: 25250
      provider: dav
      director: {user: director, password: director-password}
      agent: {user: agent, password: agent-password}

    director:
      address: 127.0.0.1
      name: micro
      db: *db
      cpi_job: cpi

    hm:
      http: {user: hm, password: hm-password}
      director_account: {user: admin, password: admin}

    openstack: &openstack
      auth_url: ${openstack_auth_url}
      username: ${openstack_username}
      api_key: ${openstack_api_key}
      tenant: ${openstack_tenant}
      region: #leave this blank
      endpoint_type: publicURL
      default_key_name: ${openstack_default_key_name}
      default_security_groups:
      - ${openstack_security_group}
      state_timeout: ${openstack_state_timeout}
      wait_resource_poll_interval: 5
      connection_options:
        connect_timeout: ${openstack_connection_timeout}
        read_timeout: ${openstack_read_timeout}
        write_timeout: ${openstack_write_timeout}

    # Tells agents how to contact nats
    agent: {mbus: "nats://nats:nats-password@${openstack_floating_ip}:4222"}

    ntp: &ntp
    - 0.north-america.pool.ntp.org
    - 1.north-america.pool.ntp.org

cloud_provider:
  template: {name: cpi, release: ${cpi_release_name}}

  # Tells bosh-micro how to SSH into deployed VM
  ssh_tunnel:
    host: ${openstack_floating_ip}
    port: 22
    user: vcap
    private_key: $working_dir/keys/bats.pem

  # Tells bosh-micro how to contact remote agent
  mbus: https://mbus-user:mbus-password@${openstack_floating_ip}:6868

  properties:
    openstack: *openstack

    # Tells CPI how agent should listen for requests
    agent: {mbus: "https://mbus-user:mbus-password@0.0.0.0:6868"}

    blobstore:
      provider: local
      path: /var/vcap/micro_bosh/data/cache

    ntp: *ntp
EOF

initver=$(cat bosh-init/version)
bosh_init="${working_dir}/bosh-init/bosh-init-${initver}-linux-amd64"
chmod +x $bosh_init

echo "deleting existing BOSH Director VM..."
$bosh_init delete ${manifest_dir}/${manifest_filename}

echo "deploying BOSH..."
$bosh_init deploy ${manifest_dir}/${manifest_filename}

