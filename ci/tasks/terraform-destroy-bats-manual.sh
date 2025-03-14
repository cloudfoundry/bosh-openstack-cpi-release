#!/bin/bash

set -e

echo "******************************"
echo "Metadata JSON passed to our destroy:"
cat terraform-cpi/metadata
echo "******************************"
echo ""

cd terraform-cpi/ci/terraform/ci/bats-manual
terraform destroy -auto-approve -input=false