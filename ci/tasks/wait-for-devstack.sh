#!/usr/bin/env bash

# Polls the DevStack Keystone endpoint until it answers, so downstream jobs don't start against a
# half-installed cloud.

set -euo pipefail

: "${AUTH_URL:?}"
: "${OS_USERNAME:?}"
: "${OS_PASSWORD:?}"
: "${OS_PROJECT:?}"

echo "waiting for DevStack Keystone at ${AUTH_URL} ..."
for i in $(seq 1 100); do
  code="$(curl -s -o /dev/null -m 5 -w '%{http_code}' "${AUTH_URL}" || echo 000)"
  if [ "${code}" = "200" ] || [ "${code}" = "300" ]; then
    echo "Keystone is up (HTTP ${code})"
    break
  fi
  echo "not ready yet (attempt ${i}, HTTP ${code}); sleeping 30s"
  sleep 30
  if [ "${i}" -eq 100 ]; then
    echo "timed out waiting for DevStack at ${AUTH_URL}"
    exit 1
  fi
done

echo "waiting for CI user auth (confirms create_project_and_user has run) ..."
for i in $(seq 1 20); do
  payload=$(jq -n \
    --arg user    "${OS_USERNAME}" \
    --arg pass    "${OS_PASSWORD}" \
    --arg project "${OS_PROJECT}" \
    '{"auth":{"identity":{"methods":["password"],"password":{"user":{"name":$user,"domain":{"name":"Default"},"password":$pass}}},"scope":{"project":{"name":$project,"domain":{"name":"Default"}}}}}')
  code="$(curl -s -o /dev/null -m 10 -w '%{http_code}' \
    -X POST "${AUTH_URL}/v3/auth/tokens" \
    -H "Content-Type: application/json" \
    -d "${payload}" \
    || echo 000)"
  if [ "${code}" = "201" ]; then
    echo "CI user auth OK — DevStack fully ready"
    exit 0
  fi
  echo "auth not ready yet (attempt ${i}, HTTP ${code}); sleeping 30s"
  sleep 30
done

echo "timed out waiting for CI user auth at ${AUTH_URL}"
exit 1
