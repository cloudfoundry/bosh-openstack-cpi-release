#!/usr/bin/env bash

set -eu

fly -t bosh-ecosystem set-pipeline -p "bosh-openstack-cpi" \
    -c ci/pipeline.yml \
    -v bosh_vcap_password=test_password_123 
