The `update-bosh-deployment` pipeline is triggered whenever there is a new release available at [https://bosh.io/releases/github.com/cloudfoundry-incubator/bosh-openstack-cpi-release](https://bosh.io/releases/github.com/cloudfoundry-incubator/bosh-openstack-cpi-release?all=1).

If a new bosh.io release is available, a pull request will be created in the bosh-deployment repo which will update Openstack CPI [version, url and sha](https://github.com/cloudfoundry/bosh-deployment/blob/24b7a9aa9e9c4455ff5f00afca4ce1ce886a0c66/openstack/cpi.yml#L6-L8).
