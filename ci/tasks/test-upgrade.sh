#!/usr/bin/env bash

set -e

source bosh-cpi-src-in/ci/tasks/utils.sh

ensure_not_replace_value dns
ensure_not_replace_value v3_e2e_flavor
ensure_not_replace_value v3_e2e_connection_timeout
ensure_not_replace_value v3_e2e_read_timeout
ensure_not_replace_value v3_e2e_state_timeout
ensure_not_replace_value v3_e2e_write_timeout
ensure_not_replace_value v3_e2e_bosh_registry_port
ensure_not_replace_value v3_e2e_api_key
ensure_not_replace_value v3_e2e_auth_url
ensure_not_replace_value v3_e2e_default_key_name
ensure_not_replace_value v3_upgrade_director_floating_ip
ensure_not_replace_value v3_upgrade_director_manual_ip
ensure_not_replace_value v3_e2e_net_cidr
ensure_not_replace_value v3_e2e_net_gateway
ensure_not_replace_value v3_e2e_net_id
ensure_not_replace_value v3_e2e_security_group
ensure_not_replace_value v3_e2e_project
ensure_not_replace_value v3_e2e_domain
ensure_not_replace_value v3_e2e_username
ensure_not_replace_value v3_e2e_private_key_data
optional_value           bosh_openstack_ca_cert

source /etc/profile.d/chruby-with-ruby-2.1.2.sh

export BOSH_INIT_LOG_LEVEL=DEBUG

upgrade_deployment_dir="${PWD}/upgrade-deployment"
deployment_dir="${PWD}/deployment"
cpi_release_name="bosh-openstack-cpi"
manifest_filename="director-manifest.yml"
private_key=${deployment_dir}/bosh.pem

echo "setting up artifacts used in $manifest_filename"
mkdir -p ${deployment_dir}
cp ./bosh-cpi-dev-artifacts/${cpi_release_name}-*.tgz ${deployment_dir}/${cpi_release_name}.tgz
cp ./bosh-release/release.tgz ${deployment_dir}/bosh-release.tgz
cp ./stemcell/stemcell.tgz ${deployment_dir}/stemcell.tgz

echo "${v3_e2e_private_key_data}" > ${private_key}
chmod go-r ${private_key}
eval $(ssh-agent)
ssh-add ${private_key}

#create director manifest as heredoc
cat > "${deployment_dir}/${manifest_filename}"<<EOF
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
        dns:     ${dns}
        static:  [${v3_upgrade_director_manual_ip}]
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
      instance_type: $v3_e2e_flavor

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
      - {name: powerdns, release: bosh}
      - {name: openstack_cpi, release: bosh-openstack-cpi}

    instances: 1
    resource_pool: default
    persistent_disk_pool: default

    networks:
      - name: private
        static_ips: [${v3_upgrade_director_manual_ip}]
        default: [dns, gateway]
      - name: public
        static_ips: [${v3_upgrade_director_floating_ip}]

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
        address: ${v3_upgrade_director_manual_ip}
        host: ${v3_upgrade_director_manual_ip}
        db: *db
        http: {user: admin, password: admin, port: ${v3_e2e_bosh_registry_port}}
        username: admin
        password: admin
        port: ${v3_e2e_bosh_registry_port}
        endpoint: http://admin:admin@${v3_upgrade_director_manual_ip}:${v3_e2e_bosh_registry_port}

      # Tells the Director/agents how to contact blobstore
      blobstore:
        address: ${v3_upgrade_director_manual_ip}
        port: 25250
        provider: dav
        director: {user: director, password: director-password}
        agent: {user: agent, password: agent-password}

      director:
        address: 127.0.0.1
        name: micro
        db: *db
        cpi_job: openstack_cpi

      hm:
        http: {user: hm, password: hm-password}
        director_account: {user: admin, password: admin}

      dns:
        address: 127.0.0.1
        db: *db

      openstack: &openstack
        auth_url: ${v3_e2e_auth_url}
        username: ${v3_e2e_username}
        api_key: ${v3_e2e_api_key}
        project: ${v3_e2e_project}
        domain:  ${v3_e2e_domain}
        region: #leave this blank
        endpoint_type: publicURL
        default_key_name: ${v3_e2e_default_key_name}
        default_security_groups:
          - ${v3_e2e_security_group}
        state_timeout: ${v3_e2e_state_timeout}
        wait_resource_poll_interval: 5
        human_readable_vm_names: true
        connection_options:
          ca_cert: $(if [ -z "$bosh_openstack_ca_cert" ]; then echo "~"; else echo "\"$(echo ${bosh_openstack_ca_cert} | sed -r  -e 's/ /\\n/g ' -e 's/\\nCERTIFICATE-----/ CERTIFICATE-----/g')\""; fi)
          connect_timeout: ${v3_e2e_connection_timeout}
          read_timeout: ${v3_e2e_read_timeout}
          write_timeout: ${v3_e2e_write_timeout}

      # Tells agents how to contact nats
      agent: {mbus: "nats://nats:nats-password@${v3_upgrade_director_manual_ip}:4222"}

      ntp: &ntp
        - 0.north-america.pool.ntp.org
        - 1.north-america.pool.ntp.org

cloud_provider:
  template: {name: openstack_cpi, release: bosh-openstack-cpi}

  # Tells bosh-micro how to SSH into deployed VM
  ssh_tunnel:
    host: ${v3_upgrade_director_floating_ip}
    port: 22
    user: vcap
    private_key: ${private_key}

  # Tells bosh-micro how to contact remote agent
  mbus: https://mbus-user:mbus-password@${v3_upgrade_director_floating_ip}:6868

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
bosh_init="${PWD}/bosh-init/bosh-init-${initver}-linux-amd64"
chmod +x $bosh_init

echo "upgrading existing BOSH Director VM..."
time $bosh_init deploy ${deployment_dir}/${manifest_filename}

# make available as output
time cp ${deployment_dir}/director-manifest* $upgrade_deployment_dir
time cp -r $HOME/.bosh_init $upgrade_deployment_dir

time bosh -n target ${v3_upgrade_director_floating_ip}
time bosh login admin admin
time bosh download manifest dummy dummy-manifest
time bosh deployment dummy-manifest

echo "recreating existing BOSH Deployment..."
time bosh -n deploy --recreate

echo "deleting deployment..."
time bosh -n delete deployment dummy

echo "cleaning up director..."
time bosh -n cleanup --all
