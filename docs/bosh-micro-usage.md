## Experimental `bosh-micro` usage

!!! `bosh-micro` CLI is still being worked on !!!

To start experimenting with bosh-openstack-cpi release and new bosh-micro cli:

1. Create a deployment directory

```
mkdir my-micro
```

1. Create `manifest.yml` inside deployment directory with following contents

```
---
name: micro

networks:
- name: vip
  type: vip
- name: manual
  type: manual
  cloud_properties:
    range: __PRIVATE_IP_RANGE__
    gateway: __PRIVATE_GATEWAY__
    reserved:
    - __RESERVED_PRIVATE_IP_RANGE__
    static:
    - __STATIC_IP__
    net_id: __NET_ID__
    security_groups: [__SECURITY_GROUP_NAME__]

resource_pools:
- name: default
  cloud_properties:
    instance_type: __INSTANCE_TYPE__ 

cloud_provider:
  ssh_tunnel:
    host: __PUBLIC_IP__
    port: 22
    user: vcap
    private_key: __PRIVATE_KEY_PATH__
  registry: &registry
    username: __REGISTRY_USERNAME__
    password: __REGISTRY_PASSWORD__
    port: __REGISTRY_PORT__
    host: localhost
  mbus: https://__MBUS_USERNAME__:__MBUS_PASSWORD__@__PUBLIC_IP__:__MBUS_PORT__
  properties:
    blobstore:
      provider: local
      path: /var/vcap/micro_bosh/data/cache
    registry: *registry
    ntp: []
    openstack: &openstack_properties
      auth_url: __OPENSTACK_AUTH_URL__
      username: __OPENSTACK_USERNAME__
      api_key: __OPENSTACK_API_KEY__
      tenant: __OPENSTACK_TENANT__
      region: __OPENSTACK_REGION__
      endpoint_type: publicURL
      default_key_name: __OPENSTACK_DEFAULT_KEY_NAME__
      default_security_groups:
      - __OPENSTACK_SECURITY_GROUP_NAME__
      private_key: __PRIVATE_KEY_PATH__
      state_timeout: 300.0
      wait_resource_poll_interval: 5
      connection_options:
        connect_timeout: 60.0
    agent:
      mbus: https://__MBUS_USERNAME__:__MBUS_PASSWORD__@0.0.0.0:__MBUS_PORT__

jobs:
- name: bosh
  templates:
  - name: nats
  - name: redis
  - name: postgres
  - name: powerdns
  - name: blobstore
  - name: director
  - name: health_monitor
  - name: registry
  - name: bosh_openstack_cpi
  networks:
  - name: vip
    static_ips:
    - __PUBLIC_IP__
  - name: manual
    static_ips:
    - __STATIC_IP__
  properties:
    nats:
      user: "nats"
      password: "nats"
      auth_timeout: 3
      address: __PUBLIC_IP__
    redis:
      address: "127.0.0.1"
      password: "redis"
      port: 25255
    postgres: &bosh_db
      adapter: "postgres"
      user: "postgres"
      password: "postgres"
      host: "127.0.0.1"
      database: "bosh"
      port: 5432
    blobstore:
      address: __PUBLIC_IP__
      director:
        user: "director"
        password: "director"
      agent:
        user: "agent"
        password: "agent"
      provider: "dav"
    director:
      address: "127.0.0.1"
      name: "micro"
      port: 25555
      db: *bosh_db
      backend_port: 25556
    registry:
      address: "127.0.0.1"
      db: *bosh_db
      http:
        user: "admin"
        password: "admin"
        port: __REGISTRY_PORT__
    hm:
      http:
        user: "hm"
        password: "hm"
      director_account:
        user: "admin"
        password: "admin"
    dns:
      address: "127.0.0.1"
      domain_name: "microbosh"
      db: *bosh_db
    ntp: []
    openstack: *openstack_properties
```

1. Set deployment

```
bosh-micro deployment my-micro/manifest.yml
```

1. Kick off a deploy

```
bosh-micro deploy ~/Downloads/bosh-openstack-cpi-?.tgz ~/Downloads/bosh-stemcell-2751-openstack-kvm-ubuntu-trusty-go_agent.tgz
```
