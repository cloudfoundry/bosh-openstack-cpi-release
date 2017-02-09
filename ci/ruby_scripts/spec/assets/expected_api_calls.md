### All calls for API endpoint 'image (glance)'
```
POST /v2/images body: {"name":"<name>","disk_format":"qcow2","container_format":"bare","visibility":"private","version":"<version>","os_type":"linux","os_distro":"ubuntu","architecture":"x86_64","auto_disk_config":"true","hypervisor_type":"kvm"}
```
### All calls for API endpoint 'network (neutron)'
```
GET /v2.0/ports?device_id=<device_id>&name=<name>
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
```
