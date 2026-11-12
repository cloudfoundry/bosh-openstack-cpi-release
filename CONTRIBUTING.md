# Contributing to bosh-openstack-cpi-release

## Contributor License Agreement

All contributors must be covered by a Contributor License Agreement. [EasyCLA](https://corporate.v1.easycla.lfx.linuxfoundation.org/) will prompt you automatically when you open your first pull request.

- **Individual contributors**: sign the individual CLA yourself via EasyCLA.
- **Corporate contributors**: an authorized company representative signs the corporate CLA; individual employees are then approved by the company and do not need to sign separately. If your company approves contributors through a GitHub organization, your membership in that organization must be **public** so EasyCLA can recognize you.

If you'd like to review the agreements before signing:

- [Individual CLA](https://www.cloudfoundry.org/wp-content/uploads/icla.pdf)
- [Corporate CLA](https://www.cloudfoundry.org/wp-content/uploads/ccla.pdf)

Configure your Git identity to match your submitted CLA **before creating any commits**. If you have existing commits with a different identity, amend them with `git commit --amend --reset-author`:

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

- Follow the [Initializing a BOSH environment on OpenStack](https://bosh.io/docs/init-openstack/) guide to deploy a BOSH director. Override the CPI release reference in the manifest with the locally built tarball (e.g. via an ops file or `url: file://...`) so the deployment uses your local changes rather than the published release from bosh.io.
