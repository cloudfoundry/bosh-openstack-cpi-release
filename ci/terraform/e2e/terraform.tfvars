# copy to terraform.tfvars and replace params

auth_url = "https://cluster-4.eu-de-1.cloud.sap:5000/v3"
user_name = "cpi-dev-user"
password = "cpi-dev-user-secret"
domain_name = "HCP_CF_01"
project_name = "hamburg"
insecure = "true"
prefix = "test-terraform"

ext_net_name = "HCP-CF-DEV-773"
ext_net_id = "90e5af93-b59b-46ab-8a3e-0febe1a6b9ad"
ext_net_cidr = "172.18.104.0/23"
region_name = "eu-de-1"
# Network cidr where concourse is running in. Use project external network cidr, if it runs within OpenStack
# or cidr 0.0.0.0/0 to allow all TCP communication on port 6868
concourse_external_network_cidr = "172.18.104.0/23"
availability_zone = "rot_2"
v3_e2e_default_key_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDoF1V6whWNpGqOvSKhwDwgHpMKHgqLzx9xq07C+krEzPP77EWbcBc7lO7t3m47MLLBTyoBeYSZlEsol25Jn8xevGV/Iw9NV5HH1VBT8l4UMbnYxPE77x7AhR5AqIN6IJtSsnLLZ7mmkFmKKxfn3UBDqRPTzVGnuISm4MKmBVD8ZJNPMj6njH5/kF33cE9Z/LzPEWPpHzRXQTmfHIaKm9jPf/fSjgDivEJQKzwZBQaEqc3H5M5FmuNafyNhKQyDrUOED2k5U5jcfvjCL/VVfbDj3j4BK8rUKOOfjeJQ3zxvlFpH1WXS09CUPAhz5MYE73B0JL/IPsPWHNHmc5grHOTytx2PWTmGZMSHmtQsPNIH6rn3+ZiGeK6esre4z4BKUB+6A3MKtz9jSWMcprOxZwakVrJshRQEv5DNt5ZxbeUZM6bONGE1zmnVrQtGOzrp2lPiKDHwnaVz6hplHuBMquz5UHNCPU5vIxkbALi55HgvNWFfFAp7YDKarDNJ0IiLFcRLj73FZC/1uqx4IyRe8NV9xz2s2CkYWMsOrAW87oJBVCW8WrOxZG4XgJsSnVcFFz4D2MmlYbu3d9QURVxxID0tkkFFEiXm6HllT6oa0znbPfxlu7s5suDgghPTDTo0idYc57SH9HapzpnQyuA+XvdZgU/Bfr8ON6ZwsQ1Pe44d1Q== vcap@jumpbox"
e2e_net_cidr = "10.0.42.0/24"
e2e_net_allocation_pool_start = "10.0.42.200"
e2e_net_allocation_pool_end = "10.0.42.254"
director_private_ip_host = "20"
no_dhcp_net_1_cidr = "10.0.43.0/24"
no_dhcp_net_2_cidr = "10.0.44.0/24"