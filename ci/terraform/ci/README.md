# Using the Terraform Scripts

There are 3 reuse modules `base`, `bats` and `lifecycle`. There are also three modules leveraging the reuse modules:
- [lifecycle](./lifecycle/)
- [bats](./bats/)
- [ci](./)

These are the modules intended to be run. Terraform generally considers all `.tf` files within a folder being part of a module.

## Variables

The [variable template file](./terraform.tfvars.template) works for all three modules. 

## Examples

```bash
# setup tenant for lifecycle tests
$ terraform apply /path/to/cpi/repo/ci/terraform/ci/lifecycle
```

```bash
# setup tenant for the whole cpi pipeline
$ terraform apply /path/to/cpi/repo/ci/terraform/ci
```



