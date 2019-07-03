The `auto-update` pipeline automatically updates gems and bosh packages before creating a pull request in this repo.

The `update-packages` job is triggered whenever there is a new package version of ruby, rubygems, bundler, libyaml available as part of the [ruby-release](https://github.com/bosh-packages/ruby-release). This release is vendored into the CPI via [`bosh vendor-package`](https://bosh.io/docs/package-vendoring).

New versions of the the ruby-release are identified with the [dynamic-metalink-resource](https://github.com/dpb587/dynamic-metalink-resource). In this concourse resource, a `version_check` script with custom logic must be provided which runs periodically in the `check` step of the concourse resource. Also,  a `metalink_get` script with custom logic must be provided which runs in the `in` script of the concourse resource. This script defines how a [metalink](https://tools.ietf.org/html/rfc5854) file gets created based on the latest version determinded in the `check` script.
The metalink file gets used in the `in` script in order to download the package.

The `update-gems` job is triggered periodically. It calls `bundle update` which updates all gems of the [Gemfile](https://github.com/cloudfoundry/bosh-openstack-cpi-release/blob/master/src/bosh_openstack_cpi/Gemfile) ignoring the previously installed gems specified in the [Gemfile.lock](https://github.com/cloudfoundry/bosh-openstack-cpi-release/blob/master/src/bosh_openstack_cpi/Gemfile.lock).
