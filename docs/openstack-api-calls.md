### All calls for API endpoint 'volume (cinder)'
```
POST /v1/<tenant_id>/volumes body: {"volume":{"display_name":"volume-<resource_id>","display_description":"<display_description>","size":"<size>","availability_zone":"<availability_zone>"}}
POST /v1/<tenant_id>/volumes body: {"volume":{"display_name":"volume-<resource_id>","display_description":"<display_description>","size":"<size>","volume_type":"SSD","availability_zone":"<availability_zone>"}}
POST /v1/<tenant_id>/volumes body: {"volume":{"display_name":"volume-<resource_id>","display_description":"<display_description>","size":"<size>"}}
POST /v1/<tenant_id>/volumes body: {"volume":{"display_name":"volume-<resource_id>","display_description":null,"size":"<size>","imageRef":"<resource_id>","volume_type":"SSD"}}
POST /v1/<tenant_id>/volumes body: {"volume":{"display_name":"volume-<resource_id>","display_description":null,"size":"<size>","imageRef":"<resource_id>"}}
GET /v1/<tenant_id>/volumes/<resource_id> 
```

### All calls for API endpoint 'image (glance)'
```
GET / 
POST /v1.1/images 
DELETE /v1.1/images/<resource_id> 
GET /v1.1/images/detail 
```

### All calls for API endpoint 'compute (nova)'
```
GET /v2/<tenant_id>//servers/<resource_id>/os-volume_attachments 
GET /v2/<tenant_id>/flavors/detail.json 
GET /v2/<tenant_id>/images/detail.json 
GET /v2/<tenant_id>/os-floating-ips.json 
GET /v2/<tenant_id>/os-keypairs.json 
GET /v2/<tenant_id>/os-security-groups.json 
POST /v2/<tenant_id>/os-snapshots body: {"snapshot":{"volume_id":"<resource_id>","display_name":"snapshot-<resource_id>","display_description":"<display_description>","force":true}}
GET /v2/<tenant_id>/os-snapshots/<resource_id> 
DELETE /v2/<tenant_id>/os-snapshots/<resource_id> 
DELETE /v2/<tenant_id>/os-volumes/<resource_id> 
GET /v2/<tenant_id>/os-volumes/<resource_id> 
POST /v2/<tenant_id>/os-volumes_boot.json body: {"server":{"flavorRef":"<resource_id>","imageRef":"<resource_id>","name":"<name>","user_data":"<user_data>","key_name":"<key_name>","security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>","fixed_ip":"<fixed_ip>"}],"block_device_mapping":[{"delete_on_termination":"1","device_name":"/dev/vda","volume_id":"<resource_id>","volume_size":"<volume_size>"}]}}
POST /v2/<tenant_id>/servers.json body: {"server":{"flavorRef":"<resource_id>","imageRef":"<resource_id>","name":"<name>","user_data":"<user_data>","key_name":"<key_name>","security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>"}]}}
POST /v2/<tenant_id>/servers.json body: {"server":{"flavorRef":"<resource_id>","imageRef":"<resource_id>","name":"<name>","user_data":"<user_data>","key_name":"<key_name>","security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>","fixed_ip":"<fixed_ip>"}]}}
POST /v2/<tenant_id>/servers.json body: {"server":{"flavorRef":"<resource_id>","imageRef":"<resource_id>","name":"<name>","availability_zone":"<availability_zone>","user_data":"<user_data>","key_name":"<key_name>","security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>","fixed_ip":"<fixed_ip>"}]}}
POST /v2/<tenant_id>/servers.json body: {"server":{"flavorRef":"<resource_id>","imageRef":"<resource_id>","name":"<name>","user_data":"<user_data>","key_name":"<key_name>","config_drive":true,"security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>"}]}}
POST /v2/<tenant_id>/servers.json body: {"server":{"flavorRef":"<resource_id>","imageRef":"<resource_id>","name":"<name>","availability_zone":"<availability_zone>","user_data":"<user_data>","key_name":"<key_name>","security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>"}]}}
DELETE /v2/<tenant_id>/servers/<resource_id> 
PUT /v2/<tenant_id>/servers/<resource_id>.json body: {"server":{"name":"<name>"}}
GET /v2/<tenant_id>/servers/<resource_id>.json 
POST /v2/<tenant_id>/servers/<resource_id>/metadata.json body: {"metadata":{"index":"0"}}
POST /v2/<tenant_id>/servers/<resource_id>/metadata.json body: {"metadata":{"job":"openstack_cpi_spec"}}
POST /v2/<tenant_id>/servers/<resource_id>/metadata.json body: {"metadata":{"registry_key":"vm-<resource_id>"}}
POST /v2/<tenant_id>/servers/<resource_id>/metadata.json body: {"metadata":{"deployment":"deployment"}}
GET /v2/<tenant_id>/servers/<resource_id>/metadata/registry_key 
POST /v2/<tenant_id>/servers/<resource_id>/os-volume_attachments body: {"volumeAttachment":{"volumeId":"<resource_id>","device":"<device>"}}
DELETE /v2/<tenant_id>/servers/<resource_id>/os-volume_attachments/<resource_id> 
GET /v2/<tenant_id>/servers/detail.json 
```

### All calls for API endpoint 'network (neutron)'
```
GET / 
GET /v2.0/networks/<resource_id> 
```

### All calls for API endpoint 'identity (keystone)'
```
POST /v2.0/tokens body: {"auth":{"passwordCredentials":{"username":"<username>","password":"<password>"},"tenantName":"<tenantName>"}}
POST /v3/auth/tokens body: {"auth":{"identity":{"methods":["password"],"password":{"user":{"password":"<password>","domain":{"name":"<name>"},"name":"<name>"}}},"scope":{"project":{"name":"<name>","domain":{"name":"<name>"}}}}}
```

