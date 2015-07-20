#!/usr/bin/env bash

set -e -x

ensure_not_replace_value() {
  local name=$1
  local value=$(eval echo '$'$name)
  if [ "$value" == 'replace-me' ]; then
    echo "environment variable $name must be set"
    exit 1
  fi
}

ensure_not_replace_value base_os
ensure_not_replace_value network_type_to_test


####
#
# TODO:
# - check that all environment variables defined in pipeline.yml are set
# - reference stemcell like vCloud bats job does
# - upload new keypair to bluebox/mirantis with `external-cpi` tag to tell which vms have been deployed by which ci
# - use heredoc to generate deployment spec
# - copy rogue vm check from vSphere pipeline
#
####



cpi_release_name=bosh-openstack-cpi

source /etc/profile.d/chruby.sh
chruby 2.1.2

BAT_STEMCELL="$PWD/$BAT_STEMCELL"
BAT_VCAP_PRIVATE_KEY="$PWD/$BAT_VCAP_PRIVATE_KEY"
BAT_DEPLOYMENT_SPEC="$PWD/$BAT_DEPLOYMENT_SPEC"

eval $(ssh-agent)
chmod go-r $BAT_VCAP_PRIVATE_KEY
ssh-add $BAT_VCAP_PRIVATE_KEY

echo "using bosh CLI version..."
bosh version

bosh -n target $BAT_DIRECTOR

sed -i.bak s/"uuid: replace-me"/"uuid: $(bosh status --uuid)"/ $BAT_DEPLOYMENT_SPEC

cd bats
bundle install
bundle exec rspec spec
