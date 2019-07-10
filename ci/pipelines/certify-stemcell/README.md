The `certify-stemcell` runs the `e2e-(ubuntu|centos)[-config-drive]` jobs.
These end-to-end tests deploy a director running on an ubuntu stemcell which in turn deploys a [dummy release](https://github.com/pivotal-cf-experimental/dummy-boshrelease) on either an ubuntu or a centos stemcell.

The `test-upgrade-ubuntu` first deploys a director with an old bosh release and an old openstack cpi release on an old stemcell before deploying a dummy release.
It then re-deploys the director with a new bosh release and a new openstack cpi release on a new stemcell and re-deploys the dummy release.
