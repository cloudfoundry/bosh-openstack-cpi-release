#!/usr/bin/env bash

set -e

source bosh-cpi-release/ci/tasks/utils.sh

ensure_not_replace_value bosh_director_ip
ensure_not_replace_value bosh_director_username
ensure_not_replace_value bosh_director_password
ensure_not_replace_value stemcell_name
ensure_not_replace_value network_id
ensure_not_replace_value instance_flavor

source /etc/profile.d/chruby.sh
chruby 2.1.2

deployment_dir="${PWD}/deployment"
manifest_filename="dummy-manifest.yml"
dummy_release_name="dummy"
deployment_name="dummy-$(uuidgen)"

echo "setting up artifacts used in $manifest_filename"
mkdir -p ${deployment_dir}

echo "using bosh CLI version..."
bosh version

echo "targeting bosh director at ${bosh_director_ip}"
bosh -n target ${bosh_director_ip}
bosh login ${bosh_director_username} ${bosh_director_password}

echo "uploading stemcell to director..."
bosh -n upload stemcell --skip-if-exists ./stemcell/stemcell.tgz

pushd dummy-release
  echo "creating release..."
  bosh -n create release --name ${dummy_release_name}

  echo "uploading release to director..."
  bosh -n upload release --skip-if-exists
popd


#create dummy release manifest as heredoc
cat > "${deployment_dir}/${manifest_filename}"<<EOF
---
name: ${deployment_name}
director_uuid: $(bosh status --uuid)

releases:
  - name: ${dummy_release_name}
    version: latest

resource_pools:
  - name: default
    stemcell:
      name: ${stemcell_name}
      version: latest
    network: private
    size: 1
    cloud_properties:
      instance_type: ${instance_flavor}

networks:
  - name: private
    type: dynamic
    dns: [8.8.8.8]
    cloud_properties:
      net_id: ${network_id}
      security_groups: [${v3_e2e_security_group}]

jobs:
  - name: dummy
    template: dummy
    instances: 1
    resource_pool: default
    networks:
      - name : private
        default: [dns, gateway]

compilation:
  reuse_compilation_vms: true
  workers: 1
  network: private
  cloud_properties:
    instance_type: ${instance_flavor}

update:
  canaries: 1
  canary_watch_time: 30000-240000
  update_watch_time: 30000-600000
  max_in_flight: 3
EOF

pushd ${deployment_dir}
  echo "deploying dummy release..."
  bosh deployment ${manifest_filename}
  bosh -n deploy
  bosh -n delete deployment ${deployment_name}
  bosh -n cleanup --all
popd
