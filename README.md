# BOSH OpenStack CPI Release

* Documentation: [bosh.io/docs/openstack](https://bosh.io/docs/openstack/)
* Slack: [`#openstack` on cloudfoundry.slack.com](https://cloudfoundry.slack.com/messages/openstack) ([get your invite here](https://slack.cloudfoundry.org/))
* Mailing list: [cf-bosh](https://lists.cloudfoundry.org/pipermail/cf-bosh)
* CI https://bosh-ci.cpi.sapcloud.io
* Roadmap: [Pivotal Tracker](https://www.pivotaltracker.com/n/projects/1456570)

See [Initializing a BOSH environment on OpenStack](https://bosh.io/docs/init-openstack.html) for example usage.

See [List of OpenStack API calls](docs/openstack-api-calls.md) to get an idea about the necessary OpenStack configuration for using Bosh.

## Supported OpenStack Versions
We follow the [upstream OpenStack policy](https://docs.openstack.org/project-team-guide/stable-branches.html#maintenance-phases) of supported releases. A release is `Maintained` for ~18 months and then moves into `Extended Maintenance` if there are community members maintaining it. 

The OpenStack CPI runs automated tests against all OpenStack versions with status `Maintained` or `Extended Maintenance` with the help of the [OpenLab project](https://openlabtesting.org/) and our [cf-openstack-validator](https://github.com/cloudfoundry-incubator/cf-openstack-validator/). We don't test or guarantee the CPI to be working on OpenStack versions marked as `Unmaintained` or `EOL`. Check the [official OpenStack releases page](https://releases.openstack.org/) to find out about the maintenance state for a specific release.

## Development

See [development doc](CONTRIBUTING.md).
