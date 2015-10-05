#!/usr/bin/env bash

set -e

source bosh-cpi-release/ci/tasks/utils.sh

ensure_not_replace_value BOSH_OPENSTACK_AUTH_URL
ensure_not_replace_value BOSH_OPENSTACK_USERNAME
ensure_not_replace_value BOSH_OPENSTACK_API_KEY
ensure_not_replace_value BOSH_OPENSTACK_TENANT

export OS_AUTH_URL=$BOSH_OPENSTACK_AUTH_URL
export OS_USERNAME=$BOSH_OPENSTACK_USERNAME
export OS_PASSWORD=$BOSH_OPENSTACK_API_KEY
export OS_PROJECT_NAME=$BOSH_OPENSTACK_TENANT

openstack_delete_entities() {
  local entity=$1
  local list_args=$2
  local delete_args=$3
  id_list=$(openstack $entity list $list_args --format json | jq --raw-output '.[].ID')
  for id in $id_list
  do
    echo "Deleting $entity $id ..."
    openstack $entity delete $delete_args $id
  done
}

for instance in $(openstack server list --format json | jq --raw-output .[].Name)
do
  echo "Checking server $instance for attached volumes ..."
  volumes=$(openstack server show --format json $instance | jq --raw-output '.[] | select(.Field=="os-extended-volumes:volumes_attached") | .Value[].id')
  for volume in $volumes
  do
    echo "Detaching volume $volume from $instance ..."
    openstack server remove volume $instance $volume

    # Plan to delete all volumes in one pass anyway. If that does not work:
    #
    # OpenStack does not allow to delete a volume
    # until its status becomes 'available'.
    # Status turns from 'in-use' to 'available'
    # some time after deleting all attachments.
    # options = { tries: 10, sleep: 5, on: [Excon::Errors::BadRequest] }
    # Bosh::Retryable.new(options).retryer { volume.destroy }
  done
  echo "Deleting server $instance ..."
  openstack server delete $instance --wait
done

# Destroy all images and snapshots and volumes

echo "Deleting images #########################"
openstack_delete_entities "image" "--private"
echo "Deleting snapshots #########################"
openstack_delete_entities "snapshot"
echo "Deleting volumes #########################"
openstack_delete_entities "volume" "" "--force"
