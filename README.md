# BOSH OpenStack CPI Release

- Documentation: [bosh.io/docs/openstack](https://bosh.io/docs/openstack/)
- Slack: [`#openstack` on cloudfoundry.slack.com](https://cloudfoundry.slack.com/messages/openstack) ([get your invite here](https://slack.cloudfoundry.org/))
- Issues: [GitHub Issues](https://github.com/cloudfoundry/bosh-openstack-cpi-release/issues)
- CI: [bosh.ci.cloudfoundry.org](https://bosh.ci.cloudfoundry.org/teams/main/pipelines/bosh-openstack-cpi)

See [Initializing a BOSH environment on OpenStack](https://bosh.io/docs/init-openstack.html) for example usage.

See [List of OpenStack API calls](docs/openstack-api-calls.md) for an inventory of OpenStack API calls made by the CPI.

## Supported OpenStack Versions

We follow the [upstream OpenStack policy](https://docs.openstack.org/project-team-guide/stable-branches.html#maintenance-phases) on supported releases. The CPI is tested against OpenStack releases with status `Maintained` or `Extended Maintenance`. Releases marked `Unmaintained` or `EOL` are not tested or guaranteed to work. See the [official OpenStack releases page](https://releases.openstack.org/) for the current maintenance state of each release.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md).
