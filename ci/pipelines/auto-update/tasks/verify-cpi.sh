#!/usr/bin/env bash

BASE_DIR="$PWD"

mkdir $BASE_DIR/verify-cpi

pushd packages-src-out
echo 'Creating CPI release...'
bosh-go create-release --tarball=$BASE_DIR/verify-cpi/cpi-release.tgz
popd

cd $BASE_DIR/validator-src-in

mkdir stemcell
tar -cvzf stemcell.tgz stemcell
rmdir stemcell
cat > validator.yml <<EOF
---
openstack:
  auth_url: http://localhost/v3 # Keystone V3 URL
  username: novalue
  password: novalue
  domain: novalue
  project: novalue
  default_key_name: cf-validator
  default_security_groups: [default]
  boot_from_volume: false
  config_drive: ~

validator:
  use_external_ip: false
  network_id: novalue
  floating_ip: novalue
  static_ip: novalue
  private_key_path: cf-validator.rsa_id
  public_image_id: novalue
  ntp: [0.pool.ntp.org, 1.pool.ntp.org]
  mtu_size: 1500
  releases:
  - name: bosh-openstack-cpi
    url: https://bosh.io/d/github.com/cloudfoundry-incubator/bosh-openstack-cpi-release?v=33
    sha1: 86b8eedcb0a6be3e821a5d0042916180706262be

cloud_config:
  vm_types: []
EOF

echo 'Installing validator dependencies...'
bundle install

useradd -m vali

echo 'Running validator...'
sudo -H -u vali ./validate --tag cpi_only --stemcell stemcell.tgz \
    --config validator.yml \
    --cpi $BASE_DIR/verify-cpi/cpi-release.tgz \
    --verbose
