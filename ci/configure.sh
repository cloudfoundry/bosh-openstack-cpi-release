#!/usr/bin/env bash

set -eu

if [[ $(lpass status -q; echo $?) != 0 ]]; then
  echo "Login with lpass first"
  exit 1
fi

fly -t cpi set-pipeline -p "bosh-openstack-cpi" \
    -c ci/pipeline.yml \
    --load-vars-from <(lpass show -G --sync=now "bosh openstack cpi main pipeline secrets" --notes)
