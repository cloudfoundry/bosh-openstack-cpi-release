#!/usr/bin/env bash

set -e

source bosh-cpi-src-in/ci/tasks/utils.sh

init_openstack_cli_env

exit_code=0

openstack_delete_entities() {
  local entity=$1
  local list_args=$2
  local delete_args=$3
  id_list=$(openstack $entity list $list_args --format json | jq --raw-output '.[].ID')
  echo "Received list of all ${entity}s: ${id_list}"
  for id in $id_list
  do
    echo "Deleting $entity $id ..."
    openstack $entity delete $delete_args $id || exit_code=$?
  done
}

openstack_delete_ports() {
  for port in $(openstack port list --format json | jq --raw-output '.[].ID')
  do

  # don't delete ports that are:
  # 'network:floatingip', 'network:router_gateway',
  # 'network:dhcp', 'network:router_interface'
  # Maybe we could just filter for 'network:'?
    port_to_be_deleted=`neutron port-show --format json $port | jq --raw-output '. | select(.device_owner | contains("network:floatingip") or contains("network:router_gateway") or contains("network:dhcp") or contains("network:router_interface") | not ) | .id'`
    if [ ! -z ${port_to_be_deleted} ];
    then
      echo "Deleting port ${port_to_be_deleted}"
      openstack port delete ${port_to_be_deleted} || exit_code=$?
    fi
  done
}
# Destroy all images and snapshots and volumes

echo "Starting cleanup for project: $BOSH_OPENSTACK_PROJECT"
echo "openstack cli version:"
openstack --version

echo "Deleting servers #########################"
openstack_delete_entities "server"
echo "Deleting images #########################"
openstack_delete_entities "image" "--private --limit 1000"
echo "Deleting snapshots #########################"
openstack_delete_entities "snapshot"
echo "Deleting volumes #########################"
openstack_delete_entities "volume"
echo "Deleting ports #########################"
openstack_delete_ports

if [ -d "$tmpdir" ]; then
    echo "Deleting temp dir with cacert.pem"
    rm -rf "$tmpdir"
fi

exit ${exit_code}
