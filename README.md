# BOSH Openstack CPI Release

This is a BOSH release for the external Openstack CPI.

This release can be collocated with the BOSH release or used with new [bosh-micro cli](github.com/cloudfoundry/bosh-micro-cli).

## Building the release

The release requires the Ruby gem Bundler (used by the vendoring script):

```
  gem install bundler
```

With bundler installed, run the vendoring script:

```
  ./scripts/vendor_gems
```

Then create the BOSH release:

```
  bosh create release --force
```

The release is now ready for use. If everything works, commit the changes including the updated gems.

### Experimental `bosh-micro` usage

See [bosh-micro usage doc](docs/bosh-micro-usage.md)
