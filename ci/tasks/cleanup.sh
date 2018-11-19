#!/usr/bin/env bash

set -e

source bosh-cpi-src-in/ci/tasks/utils.sh

init_openstack_cli_env

OPENSTACK_PROJECT_ID=$(openstack project list --format json | jq --raw-output --arg project $BOSH_OPENSTACK_PROJECT '.[] | select(.Name == $project) | .ID')
if [ -z "$OPENSTACK_PROJECT_ID" ]; then
  echo "Error: Failed to get OpenStack project"
  exit 1
fi

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
  for port in $(openstack port list --project=$OPENSTACK_PROJECT_ID -c ID -f value)
  do

  # don't delete ports that are:
  # 'network:floatingip', 'network:router_gateway',
  # 'network:dhcp', 'network:router_interface',
  # 'network:ha_router_replicated_interface',
  # 'network:router_interface_distributed',
  # 'neutron:LOADBALANCERV2' and 'network:f5lbaasv2'
  # Maybe we could just filter for 'network:'?
    port_to_be_deleted=`openstack port show --format json $port | jq --raw-output '. | select(.device_owner | contains("network:floatingip") or contains("network:router_gateway") or contains("network:dhcp") or contains("network:router_interface") or contains("network:ha_router_replicated_interface") or contains("neutron:LOADBALANCERV2") or contains("network:f5lbaasv2") or contains("network:router_centralized_snat") or contains("network:router_interface_distributed") | not ) | .id'`
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
openstack_delete_entities "image" "--private --limit 1000 --property owner=$OPENSTACK_PROJECT_ID"
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
