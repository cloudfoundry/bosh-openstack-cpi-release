### All calls for API endpoint 'cloudformation (heat-cfn)'
### All calls for API endpoint 'compute (nova)'
```
POST /v2.1/<tenant_id>/servers/<resource_id>/metadata body: {"metadata":"<metadata>"}
```
### All calls for API endpoint 'compute_legacy (nova_legacy)'
### All calls for API endpoint 'identity (keystone)'
### All calls for API endpoint 'image (glance)'
```
POST /v2/images body: {"name":"<name>","disk_format":"qcow2","container_format":"bare","visibility":"private","version":"<version>","os_type":"linux","os_distro":"ubuntu","architecture":"x86_64","auto_disk_config":"true","hypervisor_type":"kvm"}
```
### All calls for API endpoint 'network (neutron)'
```
GET /v2.0/ports?device_id=<device_id>&network_id=<network_id>
POST /v2.0/lbaas/pools/<resource_id>/members body: {"member":{"address":"<address>","protocol_port":"<protocol_port>","subnet_id":"<resource_id>"}}
```
### All calls for API endpoint 'object-store (Objectstore)'
### All calls for API endpoint 'object-store-infra (Objectstore-Infra)'
### All calls for API endpoint 'object-store-test (Objectstore-Test)'
### All calls for API endpoint 'orchestration (heat)'
### All calls for API endpoint 'volume (cinder)'
### All calls for API endpoint 'volumev2 (cinderv2)'
```
DELETE /v2/<tenant_id>/volumes/<resource_id>
GET /v2/<tenant_id>/volumes/<resource_id>
POST /v2/<tenant_id>/volumes body: {"volume":{"name":"<name>","description":"<description>","size":"<size>"}}
POST /v2/<tenant_id>/volumes/<resource_id>/metadata body: {"metadata":"<metadata>"}
```
### All calls for API endpoint 'volumev3 (cinderv3)'
