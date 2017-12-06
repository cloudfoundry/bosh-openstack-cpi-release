### All calls for API endpoint 'compute (nova)'
```
POST /v2/<tenant_id>/servers/<resource_id>/metadata.json body: {"metadata":"<metadata>"}
```
### All calls for API endpoint 'image (glance)'
```
POST /v2/images body: {"name":"<name>","disk_format":"qcow2","container_format":"bare","visibility":"private","version":"<version>","os_type":"linux","os_distro":"ubuntu","architecture":"x86_64","auto_disk_config":"true","hypervisor_type":"kvm"}
```
### All calls for API endpoint 'network (neutron)'
```
GET /v2.0/ports?device_id=<device_id>&name=<name>
POST /v2.0/lbaas/pools/<resource_id>/members body: {"member":{"address":"<address>","protocol_port":"<protocol_port>","subnet_id":"<resource_id>"}}
```
### All calls for API endpoint 'volume (cinder)'
```
DELETE /v1/<tenant_id>/volumes
GET /v1/<tenant_id>/volumes
POST /v1/<tenant_id>/volumes body: {"volume":{"display_name":"volume-<resource_id>","display_description":"<display_description>","size":"<size>","atest":"<test>"}}
POST /v1/<tenant_id>/volumes body: {"volume":{"display_name":"volume-<resource_id>","display_description":"<display_description>","size":"<size>","flavorRef":"<flavorRef_id>","btest":"<test>"}}
```
### All calls for API endpoint 'volumev2 (cinderv2)'
```
POST /v2/<tenant_id>/volumes body: {"volume":{"display_name":"volume-<resource_id>","display_description":"<display_description>","size":"<size>","btest":"<test>"}}
POST /v2/<tenant_id>/volumes/<resource_id>/metadata body: {"metadata":"<metadata>"}
```
