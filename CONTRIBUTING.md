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

### Running manual tests
*Note:* This is not required for opening a pull request. Having green unit tests is good enough from our perspective.

If you still want to run manual tests (e.g. in order to validate your use case) this is how you do it: 

- Create a dev release and deploy a BOSH director using it. 
 
- If you changed any ruby dependency, run the vendoring script first:
    
    ```bash
    $ ./src/bosh_openstack_cpi/vendor_gems
    ```

- Create the BOSH release:

    ```bash
    $ bosh create-release --force --tarball=/home/workspace/bosh-openstack-cpi-release.tgz
    ```

- Deploy a BOSH Director using your CPI release (see [bosh.io](http://bosh.io/docs/init-openstack.html#create-manifest))

