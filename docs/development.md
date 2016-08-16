## Development

### Prerequisites:
- ruby 2.x
- bundler

### Running unit tests
```bash
$ cd src/bosh_openstack_cpi
$ bundle install
$ bundle exec rspec spec/unit
```

### Running integration tests
- Download & extract BOSH stemcell from [bosh.io](http://bosh.io/stemcells/bosh-openstack-kvm-ubuntu-trusty-go_agent)
- Find or create an OpenStack project/tenant
- Create networks
  - DHCP network
  - 2 non-DHCP networks
- Create a key pair by executing
```bash
$ ssh-keygen -t rsa -b 4096 -N "" -f bosh-lifecycle.rsa_id
```
  - Upload the generated public key to OpenStack as `bosh-lifecycle`
- Create configuration file
  ```bash
  $ mkdir -p <temp dir>
  $ cp docs/lifecycle-test-config-template.yml <temp dir>/lifecycle-test-config.yml
  ```
  - Replace all '<replace-me>' with appropriate values
- Run tests
  ```bash
  $ export LIFECYCLE_ENV_FILE=<temp dir>/lifecycle-test-config.yml
  $ bundle exec rspec spec/integration 
  # If keystone v2 is not available/configured:
  $ bundle exec rspec spec/integration --exclude-pattern spec/integration/lifecycle_v2_spec.rb
  ```


### Create a dev release for manual testing
With bundler installed, run the vendoring script:

```bash
$ ./scripts/vendor_gems
```

Then create the BOSH release:

```bash
$ bosh create release --force
```

The release is now ready for use. If everything works, commit the changes including the updated gems.
