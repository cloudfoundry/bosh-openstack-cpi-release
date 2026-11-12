# OpenStack API calls made by the BOSH OpenStack CPI

The CPI uses [gophercloud](https://github.com/gophercloud/gophercloud) as its OpenStack client library.

## compute (nova)

```text
DELETE /v2.1/servers/{id}
DELETE /v2.1/servers/{id}/metadata/{key}
DELETE /v2.1/servers/{id}/os-volume_attachments/{attachment_id}
GET    /v2.1/flavors/detail
GET    /v2.1/os-keypairs/{name}
GET    /v2.1/servers/{id}
GET    /v2.1/servers/{id}/metadata
GET    /v2.1/servers/{id}/os-volume_attachments
POST   /v2.1/servers
POST   /v2.1/servers/{id}/action  (reboot)
POST   /v2.1/servers/{id}/metadata
POST   /v2.1/servers/{id}/os-volume_attachments
PUT    /v2.1/servers/{id}
```

## identity (keystone)

```text
GET    /                    (version discovery, only when auth_url has no version suffix)
POST   /v3/auth/tokens
```

## image (glance)

```text
DELETE /v2/images/{id}
GET    /v2/images/{id}
POST   /v2/images
PUT    /v2/images/{id}/file
```

## network (neutron)

```text
DELETE /v2.0/ports/{id}
GET    /v2.0/floatingips?floating_ip_address={ip}
GET    /v2.0/ports?device_id={id}
GET    /v2.0/ports?device_id={id}&network_id={id}
GET    /v2.0/ports?fixed_ips=ip_address={ip}
GET    /v2.0/ports?network_id={id}&fixed_ips=ip_address={ip}
GET    /v2.0/security-groups
GET    /v2.0/security-groups/{id}
GET    /v2.0/subnets?network_id={id}
POST   /v2.0/ports
PUT    /v2.0/floatingips/{id}
```

## load balancer (octavia)

```text
DELETE /v2.0/lbaas/pools/{id}/members/{id}
GET    /v2.0/lbaas/listeners/{id}
GET    /v2.0/lbaas/loadbalancers/{id}
GET    /v2.0/lbaas/pools/{id}
GET    /v2.0/lbaas/pools/{id}/members
GET    /v2.0/lbaas/pools?name={name}
POST   /v2.0/lbaas/pools/{id}/members
```

## block storage (cinder v3)

Paths below are relative to the Cinder v3 service endpoint. When the catalog
endpoint is project-scoped (`…/v3/{project_id}`), gophercloud appends them
directly; when it is unscoped (`…/v3`), no project ID appears in the path.

```text
DELETE /snapshots/{id}
DELETE /volumes/{id}
GET    /snapshots/{id}
GET    /volumes/{id}
POST   /snapshots
POST   /snapshots/{id}/metadata
POST   /volumes
POST   /volumes/{id}/action  (os-extend)
PUT    /volumes/{id}         (metadata update)
```
### All calls for API endpoint 'image (glance)'
```
DELETE /v2/images/<resource_id>
GET /v2/images/<resource_id>
GET /v2/images/non-existing-id
POST /v2/images body: {"name":"<name>","disk_format":"qcow2","container_format":"bare","visibility":"private","version":"<version>","os_type":"linux","os_distro":"ubuntu","architecture":"x86_64","auto_disk_config":"true","hypervisor_type":"kvm"}
PUT /v2/images/<resource_id>/file
```
### All calls for API endpoint 'network (neutron)'
```
DELETE /v2.0/lbaas/pools/<resource_id>/members/<resource_id>
DELETE /v2.0/ports/<resource_id>
GET /v2.0/floatingips?floating_ip_address=<floating_ip_address>
GET /v2.0/lbaas/loadbalancers/<resource_id>
GET /v2.0/lbaas/pools/<resource_id>
GET /v2.0/lbaas/pools?name=<name>
GET /v2.0/networks/<resource_id>
GET /v2.0/ports/<resource_id>
GET /v2.0/ports?device_id=<device_id>
GET /v2.0/ports?device_id=<device_id>&network_id=<network_id>
GET /v2.0/ports?fixed_ips=["ip_address=<ip_address>", {"network_id":"<network_id>"}]
GET /v2.0/ports?fixed_ips=ip_address=<ip_address>
GET /v2.0/security-groups
GET /v2.0/subnets?network_id=<network_id>
POST /v2.0/lbaas/pools/<resource_id>/members body: {"member":{"address":"<address>","protocol_port":"<protocol_port>","subnet_id":"<resource_id>"}}
POST /v2.0/ports body: {"port":{"network_id":"<network_id>","fixed_ips":[{"ip_address":"<ip_address>"}],"security_groups":["<resource_id>"],"allowed_address_pairs":[{"ip_address":"<ip_address>"}]}}
POST /v2.0/ports body: {"port":{"network_id":"<network_id>","fixed_ips":[{"ip_address":"<ip_address>"}],"security_groups":["<resource_id>"]}}
PUT /v2.0/floatingips/<resource_id> body: {"floatingip":{"port_id":"<resource_id>"}}
PUT /v2.0/floatingips/<resource_id> body: {"floatingip":{"port_id":null}}
```
### All calls for API endpoint 'object-store (Objectstore)'
### All calls for API endpoint 'object-store-infra (Objectstore-Infra)'
### All calls for API endpoint 'object-store-test (Objectstore-Test)'
### All calls for API endpoint 'orchestration (heat)'
### All calls for API endpoint 'placement (placement)'
### All calls for API endpoint 'resources (resources)'
### All calls for API endpoint 'volume (cinder)'
### All calls for API endpoint 'volumev2 (cinderv2)'
### All calls for API endpoint 'volumev3 (cinderv3)'
```
DELETE /v3/<tenant_id>/snapshots/<resource_id>
DELETE /v3/<tenant_id>/volumes/<resource_id>
GET /v3/<tenant_id>/snapshots/<resource_id>
GET /v3/<tenant_id>/volumes/<resource_id>
POST /v3/<tenant_id>/snapshots body: {"snapshot":{"volume_id":"<resource_id>","name":"<name>","description":"<description>","force":true}}
PUT /v3/<tenant_id>/snapshots/<resource_id>/metadata body: {"metadata":"<metadata>"}
POST /v3/<tenant_id>/volumes body: {"volume":{"name":"<name>","description":"<description>","size":"<size>","availability_zone":"<availability_zone>"}}
POST /v3/<tenant_id>/volumes body: {"volume":{"name":"<name>","description":"<description>","size":"<size>"}}
POST /v3/<tenant_id>/volumes/<resource_id>/action body: {"os-extend":{"new_size":"<new_size>"}}
PUT /v3/<tenant_id>/volumes/<resource_id> body: {"volume":{"metadata":"<metadata>"}}
```
