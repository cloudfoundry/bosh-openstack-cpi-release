#!/bin/bash

cd "$(dirname "$0")"

echo "Downloading lifecycle.log from concourse pipeline..."

BUILDID=$(fly -t aws builds -j bosh-openstack-cpi-cloud7-prod/publish-api-calls | head -n 1 |cut -f 1 -d' ')
fly -t aws hijack -b $BUILDID -s publish cat lifecycle-log/lifecycle.log > lifecycle_full.log

if [[ $? -ne 0 ]]; then
    exit 1
fi

echo "Getting current line of catalog v2 and v3 log..."

grep -e 'excon.response.*/v3/auth/tokens.*"catalog":' lifecycle_full.log | tail -n 1 > catalog_v3.log
sed -e 's/"catalog":\[/"serviceCatalog":\[/g' -e 's/"token":{/"access":{/g' catalog_v3.log > catalog_v2.log

echo "Retrieving / updating reasonable selection from lifecycle logs..."

:>lifecycle.log
grep -e 'POST.*:8774/v2.1/.*/servers/.*/metadata ' lifecycle_full.log | tail -n 1 >> lifecycle.log
grep -e 'POST.*:9292/v2/images ' lifecycle_full.log | tail -n 1 >> lifecycle.log
grep -e 'GET.*:9696/v2.0/ports .*"network_id":' lifecycle_full.log | tail -n 1 >> lifecycle.log
grep -e 'POST.*:9696/v2.0/lbaas/pools/.*/members ' lifecycle_full.log | tail -n 1 >> lifecycle.log
grep -e 'GET.*:8776/v2/.*/volumes/[0-9a-f-]\+ ' lifecycle_full.log | tail -n 1 >> lifecycle.log
grep -e 'DELETE.*:8776/v2/.*/volumes/[0-9a-f-]\+ ' lifecycle_full.log | tail -n 1 >> lifecycle.log
grep -e 'POST.*:8776/v2/.*/volumes/.*/metadata ' lifecycle_full.log | tail -n 1 >> lifecycle.log
grep -e 'POST.*:8776/v2/.*/volumes ' lifecycle_full.log | tail -n 1 >> lifecycle.log

echo "Removing landscape specifics from example log entries..."

sed -e 's@"\(region[_id]*\)":"[^"]*@"\1":"my-openstack-region@g' \
    -e 's@"[hH]ost":"[^"]*@"host":"my.openstack.domain.com@g' \
    -e 's@https*://[^"|^:|^/]*@https://my.openstack.domain.com@g' \
    -e 's@\([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\}@1.2.3.4@g' \
    -i .bak lifecycle.log catalog_v3.log catalog_v2.log

echo "running tests..."

cd ../..
bundle install
bundle exec rspec spec/

echo ""
echo -e "\033[1mlifecycle.log catalog_v3.log & catalog_v2.log updated. You may now review the changes and the test results.\033[0m"