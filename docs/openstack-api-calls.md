### All calls for API endpoint 'cloudformation (heat-cfn)'
### All calls for API endpoint 'compute (nova)'
```
DELETE /v2.1/<tenant_id>/os-server-groups/<resource_id>
DELETE /v2.1/<tenant_id>/servers/<resource_id>
DELETE /v2.1/<tenant_id>/servers/<resource_id>/os-volume_attachments/<resource_id>
GET /v2.1/<tenant_id>//servers/<resource_id>/os-volume_attachments
GET /v2.1/<tenant_id>/flavors/detail
GET /v2.1/<tenant_id>/os-keypairs
GET /v2.1/<tenant_id>/os-security-groups
GET /v2.1/<tenant_id>/os-server-groups
GET /v2.1/<tenant_id>/servers/<resource_id>
GET /v2.1/<tenant_id>/servers/<resource_id>/metadata/registry_key
POST /v2.1/<tenant_id>/os-server-groups body: {"server_group":{"name":"<name>","policies":["soft-anti-affinity"]}}
POST /v2.1/<tenant_id>/servers body: {"server":{"flavorRef":"<flavorRef_id>","name":"<name>","imageRef":"<resource_id>","availability_zone":"<availability_zone>","user_data":"<user_data>","key_name":"<key_name>","security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>","port":"<resource_id>"}]}}
POST /v2.1/<tenant_id>/servers body: {"server":{"flavorRef":"<flavorRef_id>","name":"<name>","imageRef":"<resource_id>","availability_zone":"<availability_zone>","user_data":"<user_data>","key_name":"<key_name>","security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>"}]}}
POST /v2.1/<tenant_id>/servers body: {"server":{"flavorRef":"<flavorRef_id>","name":"<name>","imageRef":"<resource_id>","user_data":"<user_data>","key_name":"<key_name>","config_drive":true,"security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>","port":"<resource_id>"},{"uuid":"<resource_id>","port":"<resource_id>"}]}}
POST /v2.1/<tenant_id>/servers body: {"server":{"flavorRef":"<flavorRef_id>","name":"<name>","imageRef":"<resource_id>","user_data":"<user_data>","key_name":"<key_name>","config_drive":true,"security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>"}]}}
POST /v2.1/<tenant_id>/servers body: {"server":{"flavorRef":"<flavorRef_id>","name":"<name>","imageRef":"<resource_id>","user_data":"<user_data>","key_name":"<key_name>","security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>","port":"<resource_id>"}]}}
POST /v2.1/<tenant_id>/servers body: {"server":{"flavorRef":"<flavorRef_id>","name":"<name>","imageRef":"<resource_id>","user_data":"<user_data>","key_name":"<key_name>","security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>"}]},"os:scheduler_hints":{"group":"<resource_id>"}}
POST /v2.1/<tenant_id>/servers body: {"server":{"flavorRef":"<flavorRef_id>","name":"<name>","imageRef":"<resource_id>","user_data":"<user_data>","key_name":"<key_name>","security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>"}]}}
POST /v2.1/<tenant_id>/servers body: {"server":{"flavorRef":"<flavorRef_id>","name":"<name>","user_data":"<user_data>","key_name":"<key_name>","security_groups":[{"name":"<name>"}],"networks":[{"uuid":"<resource_id>","port":"<resource_id>"}],"block_device_mapping_v2":[{"boot_index":"0","delete_on_termination":"1","destination_type":"volume","device_name":"/dev/vda","source_type":"image","uuid":"<resource_id>","volume_size":"<volume_size>"}]}}
POST /v2.1/<tenant_id>/servers/<resource_id>/metadata body: {"metadata":"<metadata>"}
POST /v2.1/<tenant_id>/servers/<resource_id>/os-volume_attachments body: {"volumeAttachment":{"volumeId":"<resource_id>","device":"<device>"}}
PUT /v2.1/<tenant_id>/servers/<resource_id> body: {"server":{"name":"<name>"}}
```
### All calls for API endpoint 'compute_legacy (nova_legacy)'
```
GET /
```
### All calls for API endpoint 'identity (keystone)'
```
POST /v3/auth/tokens body: {"auth":{"identity":{"methods":["password"],"password":{"user":{"password":"<password>","domain":{"name":"<name>"},"name":"<name>"}}},"scope":{"project":{"name":"<name>","domain":{"name":"<name>"}}}}}
```
### All calls for API endpoint 'image (glance)'
```
DELETE /v2/images/<resource_id>
GET /
GET /v2/images/<resource_id>
GET /v2/images/non-existing-id
POST /v2/images body: {"name":"<name>","disk_format":"qcow2","container_format":"bare","visibility":"private","version":"<version>","os_type":"linux","os_distro":"ubuntu","architecture":"x86_64","auto_disk_config":"true","hypervisor_type":"kvm"}
PUT /v2/images/<resource_id>/file
```
### All calls for API endpoint 'network (neutron)'
```
DELETE /v2.0/lbaas/pools/<resource_id>/members/<resource_id>
DELETE /v2.0/ports/<resource_id>
GET /
GET /v2.0/floatingips?floating_ip_address=<floating_ip_address>
GET /v2.0/lbaas/loadbalancers/<resource_id>
GET /v2.0/lbaas/pools/<resource_id>
GET /v2.0/lbaas/pools?name=<name>
GET /v2.0/networks/<resource_id>
GET /v2.0/ports/<resource_id>
GET /v2.0/ports?device_id=<device_id>
GET /v2.0/ports?device_id=<device_id>&network_id=<network_id>
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
### All calls for API endpoint 'volume (cinder)'
### All calls for API endpoint 'volumev2 (cinderv2)'
```
DELETE /v2/<tenant_id>/snapshots/<resource_id>
DELETE /v2/<tenant_id>/volumes/<resource_id>
GET /v2/<tenant_id>/snapshots/<resource_id>
GET /v2/<tenant_id>/volumes/<resource_id>
POST /v2/<tenant_id>/snapshots body: {"snapshot":{"volume_id":"<resource_id>","name":"<name>","description":"<description>","force":true}}
POST /v2/<tenant_id>/snapshots/<resource_id>/metadata body: {"metadata":"<metadata>"}
POST /v2/<tenant_id>/volumes body: {"volume":{"name":"<name>","description":"<description>","size":"<size>","availability_zone":"<availability_zone>"}}
POST /v2/<tenant_id>/volumes body: {"volume":{"name":"<name>","description":"<description>","size":"<size>"}}
POST /v2/<tenant_id>/volumes/<resource_id>/action body: {"os-extend":{"new_size":"<new_size>"}}
POST /v2/<tenant_id>/volumes/<resource_id>/metadata body: {"metadata":"<metadata>"}
```
### All calls for API endpoint 'volumev3 (cinderv3)'
