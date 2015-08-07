# BOSH Openstack CPI Release

* Documentation: [bosh.io/docs](https://bosh.io/docs)
* IRC: [`#bosh` on freenode](https://webchat.freenode.net/?channels=bosh)
* Mailing list: [cf-bosh](https://lists.cloudfoundry.org/pipermail/cf-bosh)
* CI: [https://main.bosh-ci.cf-app.com/pipelines/openstack-cpi](https://main.bosh-ci.cf-app.com/pipelines/openstack-cpi)
* Roadmap: [Pivotal Tracker](https://www.pivotaltracker.com/n/projects/1133984) (label:openstack)

This is a BOSH release for the Openstack CPI.

See [Initializing a BOSH environment on Openstack](https://bosh.io/docs/init-openstack.html) for example usage.

## Development

See [development doc](docs/development.md).

### Deploying concourse locally

Below instructions assume you have a local concourse running and a BOSH environment on Openstack.

See [Concourse - Getting Started](http://concourse.ci/getting-started.html)

Configure concourse with your [pipeline.yml](ci/pipeline.yml), see how [parameters are passed](http://concourse.ci/fly-cli.html#fly-configure).

```
fly configure -c ci/pipeline.yml -vf /path/to/secrets.yml
```
