#!/usr/bin/env bash

set -e

export BOSH_INIT_LOG_LEVEL=DEBUG

working_dir=$PWD
deployment_dir=$PWD/upgrade-deployment

cd ${deployment_dir}

echo "using bosh CLI version..."
bosh-go --version

echo "deleting BOSH..."
bosh-go delete-env \
    --state director-manifest-state.json \
    director-manifest.yml