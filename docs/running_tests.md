## OpenStack Prerequisites and Variables

The concourse pipeline requires some variables to be set. The easiest way is to create a file called `secrets.yml` using the [template](secrets.yml.template) and fill in the values as you go through the setup steps.

If you are setting this up for your own environment, you are probably not publishing your own releases. Some of the properties defined there are for promoting a real release only; you can fill those with anything you'd like or remove the corresponding tasks entirely from the pipeline.

All instructions include the variables to fill in `monospace`.

### External Prerequisites

- Install [concourse](http://concourse.ci/)
- Create S3 buckets for the artifacts created during the build
 - `s3_openstack_cpi_pipeline_bucket_name`
- Credentials for these S3 buckets
 - `s3_openstack_cpi_pipeline_access_key`, `s3_openstack_cpi_pipeline_secret_key`

### OpenStack Prerequisites

- Create a project where the tests can run. The `cleanup` task at the end will clean *everything* in that project!
 - `openstack_tenant`
- Fill in some infrastructure details
 - Keystone v2 auth url `openstack_auth_url_v2`
 - Keystone v3 auth url (optional) `openstack_auth_url_v3`
 - user for the tenant `openstack_username`
 - password for the tenant `openstack_api_key`
 - `openstack_flavor_with_ephemeral_disk`
 - `openstack_flavor_with_no_ephemeral_disk`
- Create SSH key pairs
 - bosh director and bats `openstack_default_key_name`
 - lifecycle tests `lifecycle_openstack_default_key_name`
 - e2e tests `v3_e2e_default_key_name`
- Create networks with DHCP enabled. Each test uses a different network so they can be run in parallel.
 - lifecycle tests `lifecycle_openstack_net_id`
 - bats ubuntu stemcell
   - `bats_dynamic_ubuntu_primary_net_id`
   - `bats_manual_ubuntu_primary_net_id`
   - `bats_manual_ubuntu_secondary_net_id`
 - bats centos stemcell
   - `bats_dynamic_centos_primary_net_id`
   - `bats_manual_centos_primary_net_id`
   - `bats_manual_centos_secondary_net_id`
 - e2e tests `v3_e2e_net_id`
 - For each network: Fill in the corresponding network properties as well
   - `..._cidr`, `..._static_range`, `..._gateway`
 - Pick the necessary IPs from the `static_range`
   - `..._manual_ip`, `..._second_manual_ip`

- Create a security group `test-group`
  - `openstack_security_group`

- Create the following rules
```
 - Egress  IPv4 Any Any          0.0.0.0/0               -
 - Ingress IPv4 Any Any             -                test-group
 - Ingress IPv4 TCP Any    <floating-network>/<cidr>     -
 - Ingress IPv4 TCP 22           <concourse-ip>          -
 - Ingress IPv4 TCP 25555        <concourse-ip>          -
 - Ingress IPv4 UDP Any    <floating-network>/<cidr>     -
```
- Create a router and connect all test networks with the external network
- Create floating IPs
  - bats ubuntu stemcell
  - `bats_dynamic_ubuntu_director_public_ip`
  - `bats_dynamic_ubuntu_floating_ip`
  - `bats_dynamic_centos_director_public_ip`
  - `bats_dynamic_centos_floating_ip`
  - `bats_manual_ubuntu_director_public_ip`
  - `bats_manual_ubuntu_floating_ip`
  - `bats_manual_centos_director_public_ip`
  - `bats_manual_centos_floating_ip`
  - `v3_e2e_floating_ip`
