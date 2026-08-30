#!/usr/bin/env bash
set -eu -o pipefail

cd bosh-openstack-cpi-release/src/openstack_cpi_golang
go run github.com/onsi/ginkgo/v2/ginkgo -r --race --randomize-all --randomize-suites integration
