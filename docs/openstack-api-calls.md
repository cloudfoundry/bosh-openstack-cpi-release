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
