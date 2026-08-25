#!/usr/bin/env bash

set -eu

fly -t "${CONCOURSE_TARGET:-bosh}" set-pipeline -p "bosh-openstack-cpi" \
    -c ci/pipeline.yml
