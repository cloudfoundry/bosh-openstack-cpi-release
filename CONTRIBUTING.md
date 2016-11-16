# Contributing to bosh-openstack-cpi-release

## Contributor License Agreement

Follow these steps to make a contribution to any of CF open source repositories:

1. Ensure that you have completed our CLA Agreement for
   [individuals](http://cloudfoundry.org/pdfs/CFF_Individual_CLA.pdf) or
   [corporations](http://cloudfoundry.org/pdfs/CFF_Corporate_CLA.pdf).

1. Set your name and email (these should match the information on your submitted CLA)

        git config --global user.name "Firstname Lastname"
        git config --global user.email "your_email@example.com"

1. If your company has signed a Corporate CLA, but sure to make the membership in your company's github organization public


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
- Download and extract BOSH stemcell from [bosh.io](http://bosh.io/stemcells/bosh-openstack-kvm-ubuntu-trusty-go_agent)
- Find or create an OpenStack project/tenant
- Create a key pair by executing
  ```bash
  $ mkdir -p <temp dir>
  $ cd <temp dir>
  $ ssh-keygen -t rsa -b 4096 -N "" -f bosh-lifecycle.rsa_id
  ```
- Prepare openstack project
  - Copy terraform configuration
    ```bash
    $ cp <cpi project>/ci/terraform/ci/lifecycle/terraform.tfvars.template terraform.tfvars
    ```
  - Replace all '<...>' with appropriate values.
  - Run terraform
    ```bash
    $ terraform get <cpi project>/ci/terraform/ci/lifecycle
    $ terraform apply <cpi project>/ci/terraform/ci/lifecycle
    ```
- Create configuration file from terraform output
  ```bash
  $ cp <cpi project>/docs/lifecycle-test-config-template.yml lifecycle-test-config.yml
  ```
  - Replace all '<replace-me>' with values from `terraform apply`
- Run tests
  ```bash
  $ export LIFECYCLE_ENV_FILE=<absolute path to temp dir>/lifecycle-test-config.yml
  $ cd <cpi project>/src/bosh_openstack_cpi
  $ bundle install
  $ bundle exec rspec spec/integration --exclude-pattern spec/integration/lifecycle_v2_spec.rb
  # If keystone v2 is available/configured:
  $ bundle exec rspec spec/integration
  ```
- Cleanup openstack project
  ```bash
  $ cd <temp dir>
  $ terraform destroy <cpi project>/ci/terraform/ci/lifecycle
  ```


### Running manual tests
*Note:* This is not required for opening a pull request. Having green unit and integration tests is good enough from our perspective.

If you still want to run manual tests (e.g. in order to validate your use case) this is how you do it: 

- Create a dev release and deploy a BOSH director using it. 
 
- If you changed any ruby dependency, run the vendoring script first:
    
    ```bash
    $ ./src/bosh_openstack_cpi/vendor_gems
    ```

- Create the BOSH release:

    ```bash
    $ bosh create release --force --with-tarball
    ```

- Deploy a BOSH Director using your CPI release (see [bosh.io](http://bosh.io/docs/init-openstack.html#create-manifest))

