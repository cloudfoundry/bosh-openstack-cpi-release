#!/usr/bin/env bash

# Polls the DevStack Keystone endpoint until it answers, so downstream jobs don't start against a
# half-installed cloud. DevStack is installed on the VM via its startup-script (~30-40 min from scratch).

set -euo pipefail

: ${AUTH_URL:?}

echo "waiting for DevStack Keystone at ${AUTH_URL} ..."
for i in $(seq 1 100); do
  code="$(curl -s -o /dev/null -m 5 -w '%{http_code}' "${AUTH_URL}" || echo 000)"
  if [ "${code}" = "200" ] || [ "${code}" = "300" ]; then
    echo "DevStack is up (HTTP ${code})"
    exit 0
  fi
  echo "not ready yet (attempt ${i}, HTTP ${code}); sleeping 30s"
  sleep 30
done

echo "timed out waiting for DevStack at ${AUTH_URL}"
exit 1
