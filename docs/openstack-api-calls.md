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
GET /v2/<tenant_id>/servers/<resource_id>.json
GET /v2/<tenant_id>/servers/<resource_id>/metadata/registry_key
GET /v2/<tenant_id>/servers/detail.json
POST /v2/<tenant_id>/os-snapshots body: {"snapshot":{"volume_id":"<resource_id>","display_name":"snapshot-<resource_id>","display_description":"<display_description>","force":true}}
POST /v2/<tenant_id>/os-volumes_boot.json body: {"server":{"flavorRef":"<resource_id>","name":"<name>","imageRef":"<resource_id>","user_data":"<user_data>","key_name":"<key_name>","security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>","fixed_ip":"<fixed_ip>"}],"block_device_mapping_v2":[{"boot_index":"0","delete_on_termination":"1","device_name":"/dev/vda","source_type":"image","uuid":"<resource_id>","volume_size":"<volume_size>"}]}}
POST /v2/<tenant_id>/servers.json body: {"server":{"flavorRef":"<resource_id>","name":"<name>","imageRef":"<resource_id>","availability_zone":"<availability_zone>","user_data":"<user_data>","key_name":"<key_name>","security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>","fixed_ip":"<fixed_ip>"}]}}
POST /v2/<tenant_id>/servers.json body: {"server":{"flavorRef":"<resource_id>","name":"<name>","imageRef":"<resource_id>","availability_zone":"<availability_zone>","user_data":"<user_data>","key_name":"<key_name>","security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>"}]}}
POST /v2/<tenant_id>/servers.json body: {"server":{"flavorRef":"<resource_id>","name":"<name>","imageRef":"<resource_id>","user_data":"<user_data>","key_name":"<key_name>","config_drive":true,"security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>","port":"<resource_id>"},{"uuid":"<resource_id>","port":"<resource_id>"}]}}
POST /v2/<tenant_id>/servers.json body: {"server":{"flavorRef":"<resource_id>","name":"<name>","imageRef":"<resource_id>","user_data":"<user_data>","key_name":"<key_name>","config_drive":true,"security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>"}]}}
POST /v2/<tenant_id>/servers.json body: {"server":{"flavorRef":"<resource_id>","name":"<name>","imageRef":"<resource_id>","user_data":"<user_data>","key_name":"<key_name>","security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>","fixed_ip":"<fixed_ip>"}]}}
POST /v2/<tenant_id>/servers.json body: {"server":{"flavorRef":"<resource_id>","name":"<name>","imageRef":"<resource_id>","user_data":"<user_data>","key_name":"<key_name>","security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>"}]}}
POST /v2/<tenant_id>/servers/<resource_id>/metadata.json body: {"metadata":{"deployment":"deployment"}}
POST /v2/<tenant_id>/servers/<resource_id>/metadata.json body: {"metadata":{"name":"<name>"}}
POST /v2/<tenant_id>/servers/<resource_id>/metadata.json body: {"metadata":{"registry_key":"vm-<resource_id>"}}
POST /v2/<tenant_id>/servers/<resource_id>/os-volume_attachments body: {"volumeAttachment":{"volumeId":"<resource_id>","device":"<device>"}}
PUT /v2/<tenant_id>/servers/<resource_id>.json body: {"server":{"name":"<name>"}}
```
### All calls for API endpoint 'identity (keystone)'
```
POST /v2.0/tokens body: {"auth":{"passwordCredentials":{"username":"<username>","password":"<password>"},"tenantName":"<tenantName>"}}
POST /v3/auth/tokens body: {"auth":{"identity":{"methods":["password"],"password":{"user":{"password":"<password>","domain":{"name":"<name>"},"name":"<name>"}}},"scope":{"project":{"name":"<name>","domain":{"name":"<name>"}}}}}
```
### All calls for API endpoint 'image (glance)'
```
DELETE /v1.1/images/<resource_id>
GET /
GET /v1.1/images/detail
POST /v1.1/images
```
### All calls for API endpoint 'network (neutron)'
```
GET /
GET /v2.0/networks/<resource_id>
GET /v2.0/ports/<resource_id>
GET /v2.0/ports?device_id=<device_id>
POST /v2.0/ports body: {"port":{"network_id":"<resource_id>","fixed_ips":[{"ip_address":"<ip_address>"}],"security_groups":["<resource_id>"]}}
```
### All calls for API endpoint 'volume (cinder)'
```
GET /v1/<tenant_id>/volumes/<resource_id>
POST /v1/<tenant_id>/volumes body: {"volume":{"display_name":"volume-<resource_id>","display_description":"<display_description>","size":"<size>","availability_zone":"<availability_zone>"}}
POST /v1/<tenant_id>/volumes body: {"volume":{"display_name":"volume-<resource_id>","display_description":"<display_description>","size":"<size>","volume_type":"SSD","availability_zone":"<availability_zone>"}}
POST /v1/<tenant_id>/volumes body: {"volume":{"display_name":"volume-<resource_id>","display_description":"<display_description>","size":"<size>"}}
```
