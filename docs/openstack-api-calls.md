### All calls for API endpoint 'cloudformation (heat-cfn)'
### All calls for API endpoint 'compute (nova)'
```
DELETE /v2/<tenant_id>/os-snapshots/<resource_id>
DELETE /v2/<tenant_id>/os-volumes/<resource_id>
DELETE /v2/<tenant_id>/servers/<resource_id>
DELETE /v2/<tenant_id>/servers/<resource_id>/os-volume_attachments/<resource_id>
GET /v2/<tenant_id>//servers/<resource_id>/os-volume_attachments
GET /v2/<tenant_id>/flavors/detail.json
GET /v2/<tenant_id>/images/detail.json
GET /v2/<tenant_id>/os-floating-ips.json
GET /v2/<tenant_id>/os-keypairs.json
GET /v2/<tenant_id>/os-security-groups.json
GET /v2/<tenant_id>/os-snapshots/<resource_id>
GET /v2/<tenant_id>/os-volumes/<resource_id>
GET /v2/<tenant_id>/os-volumes/detail
GET /v2/<tenant_id>/servers/<resource_id>.json
GET /v2/<tenant_id>/servers/<resource_id>/metadata/registry_key
GET /v2/<tenant_id>/servers/detail.json
POST /v2/<tenant_id>/os-snapshots body: {"snapshot":{"volume_id":"<resource_id>","display_name":"snapshot-<resource_id>","display_description":"<display_description>","force":true}}
POST /v2/<tenant_id>/servers.json body: {"server":{"flavorRef":"<flavorRef_id>","name":"<name>","imageRef":"<resource_id>","availability_zone":"<availability_zone>","user_data":"<user_data>","key_name":"<key_name>","security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>","fixed_ip":"<fixed_ip>"}]}}
POST /v2/<tenant_id>/servers.json body: {"server":{"flavorRef":"<flavorRef_id>","name":"<name>","imageRef":"<resource_id>","availability_zone":"<availability_zone>","user_data":"<user_data>","key_name":"<key_name>","security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>"}]}}
POST /v2/<tenant_id>/servers.json body: {"server":{"flavorRef":"<flavorRef_id>","name":"<name>","imageRef":"<resource_id>","user_data":"<user_data>","key_name":"<key_name>","config_drive":true,"security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>","port":"<resource_id>"},{"uuid":"<resource_id>","port":"<resource_id>"}]}}
POST /v2/<tenant_id>/servers.json body: {"server":{"flavorRef":"<flavorRef_id>","name":"<name>","imageRef":"<resource_id>","user_data":"<user_data>","key_name":"<key_name>","config_drive":true,"security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>"}]}}
POST /v2/<tenant_id>/servers.json body: {"server":{"flavorRef":"<flavorRef_id>","name":"<name>","imageRef":"<resource_id>","user_data":"<user_data>","key_name":"<key_name>","security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>","fixed_ip":"<fixed_ip>"}]}}
POST /v2/<tenant_id>/servers.json body: {"server":{"flavorRef":"<flavorRef_id>","name":"<name>","imageRef":"<resource_id>","user_data":"<user_data>","key_name":"<key_name>","security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>"}]}}
POST /v2/<tenant_id>/servers.json body: {"server":{"flavorRef":"<flavorRef_id>","name":"<name>","user_data":"<user_data>","key_name":"<key_name>","security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>","fixed_ip":"<fixed_ip>"}],"block_device_mapping_v2":[{"boot_index":"0","delete_on_termination":"1","destination_type":"volume","device_name":"/dev/vda","source_type":"image","uuid":"<resource_id>","volume_size":"<volume_size>"}]}}
POST /v2/<tenant_id>/servers/<resource_id>/metadata.json body: {"metadata":{"deployment":"deployment"}}
POST /v2/<tenant_id>/servers/<resource_id>/metadata.json body: {"metadata":{"name":"<name>"}}
POST /v2/<tenant_id>/servers/<resource_id>/metadata.json body: {"metadata":{"registry_key":"vm-<resource_id>"}}
POST /v2/<tenant_id>/servers/<resource_id>/os-volume_attachments body: {"volumeAttachment":{"volumeId":"<resource_id>","device":"<device>"}}
PUT /v2/<tenant_id>/servers/<resource_id>.json body: {"server":{"name":"<name>"}}
```
### All calls for API endpoint 'identity (keystone)'
```
POST /v2.0/tokens body: {"auth":{"passwordCredentials":{"username":"<username>","password":"<password>"},"tenantName":"<tenantName>"}}
```
### All calls for API endpoint 'identityv3 (keystonev3)'
```
POST /v3/auth/tokens body: {"auth":{"identity":{"methods":["password"],"password":{"user":{"password":"<password>","domain":{"name":"<name>"},"name":"<name>"}}},"scope":{"project":{"name":"<name>","domain":{"name":"<name>"}}}}}
```
### All calls for API endpoint 'image (glance)'
```
DELETE /v1/images/<resource_id>
DELETE /v2/images/<resource_id>
GET /
GET /v1/images/detail
GET /v2/images
POST /v1/images
POST /v2/images body: {"name":"<name>","disk_format":"qcow2","container_format":"bare","visibility":"private","version":"<version>","os_type":"linux","os_distro":"ubuntu","architecture":"x86_64","auto_disk_config":"true","hypervisor_type":"kvm"}
PUT /v2/images/<resource_id>/file
```
### All calls for API endpoint 'network (neutron)'
```
DELETE /v2.0/ports/<resource_id>
GET /
GET /v2.0/floatingips?floating_ip_address=255.255.255.255
GET /v2.0/networks/<resource_id>
GET /v2.0/ports/<resource_id>
GET /v2.0/ports?device_id=<device_id>
GET /v2.0/security-groups
POST /v2.0/ports body: {"port":{"network_id":"<resource_id>","fixed_ips":[{"ip_address":"<ip_address>"}],"security_groups":["<resource_id>"]}}
```
### All calls for API endpoint 'orchestration (heat)'
### All calls for API endpoint 'volume (cinder)'
### All calls for API endpoint 'volumev2 (cinderv2)'
```
GET /v2/<tenant_id>/volumes/<resource_id>
POST /v2/<tenant_id>/volumes body: {"volume":{"name":"<name>","description":"","size":"<size>","availability_zone":"<availability_zone>"}}
POST /v2/<tenant_id>/volumes body: {"volume":{"name":"<name>","description":"","size":"<size>","volume_type":"SSD","availability_zone":"<availability_zone>"}}
POST /v2/<tenant_id>/volumes body: {"volume":{"name":"<name>","description":"","size":"<size>"}}
```
