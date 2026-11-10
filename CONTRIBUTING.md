# Contributing to bosh-openstack-cpi-release

## Contributor License Agreement

All contributors must sign a Contributor License Agreement. You will be prompted to do so automatically via [EasyCLA](https://corporate.v1.easycla.lfx.linuxfoundation.org/) when you open your first pull request.

If you'd like to review the agreements before signing:

- [Individual CLA](https://www.cloudfoundry.org/wp-content/uploads/icla.pdf)
- [Corporate CLA](https://www.cloudfoundry.org/wp-content/uploads/ccla.pdf)

Set your name and email to match your submitted CLA:

```bash
git config --global user.name "Firstname Lastname"
git config --global user.email "your_email@example.com"
```

## Development

### Running manual tests

*Note:* This is not required for opening a pull request. Having green unit tests is good enough from our perspective.

If you still want to run manual tests (e.g. in order to validate your use case) this is how you do it:

- Create a dev release and deploy a BOSH director using it.

- Create the BOSH release:

    ```bash
    bosh create-release --force --tarball bosh-openstack-cpi-release.tgz
    ```

- Upload and deploy using your CPI release (see [Initializing a BOSH environment on OpenStack](https://bosh.io/docs/init-openstack/)).
