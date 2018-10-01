This repo provides the following pipeline definitions:
- [pipelines/auto-update](https://github.com/cloudfoundry-incubator/bosh-openstack-cpi-release/tree/master/ci/pipelines/auto-update)
- [pipelines/certify-stemcell](https://github.com/cloudfoundry-incubator/bosh-openstack-cpi-release/tree/master/ci/pipelines/certify-stemcell)
- [pipelines/update-bosh-deployment](https://github.com/cloudfoundry-incubator/bosh-openstack-cpi-release/tree/master/ci/pipelines/update-bosh-deployment)
- pr ([pr-pipeline.yml](https://github.com/cloudfoundry-incubator/bosh-openstack-cpi-release/blob/master/ci/pr-pipeline.yml))

The PR pipeline runs unit tests on every pull request.
It displays a staus of `pending`, `success`, or `failure` in the `Conversation` tab of the pull request.

- cpi ([pipeline.yml](https://github.com/cloudfoundry-incubator/bosh-openstack-cpi-release/blob/master/ci/pipeline.yml))

The CPI pipeline is triggered periodically and on every commit of this repo. The following jobs are run:
1. `build-candidate` runs unit tests and creates a new CPI bosh release.
2. `bats-(ubuntu|centos)-(manual|dynamic)` executes [bosh acceptance tests](https://github.com/cloudfoundry/bosh-acceptance-tests).
3. `lifecycle` runs CPI integration tests.
4. `publish-api-calls` collects all Openstack API calls from the CPI and uploads the list to [docs/openstack-api-calls.md](https://github.com/cloudfoundry-incubator/bosh-openstack-cpi-release/blob/master/docs/openstack-api-calls.md).
5. `promote-candidate` creates and commits a final release.
