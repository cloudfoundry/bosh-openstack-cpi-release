#!/usr/bin/env bash
set -eu -o pipefail

cd bosh-openstack-cpi-release/src/openstack_cpi_golang
go test ./integration/...
