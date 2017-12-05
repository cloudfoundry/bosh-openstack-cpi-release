# Building docker image

Last tested vagrant version 1.8.4. Use the latest if possible.

```
vagrant up
vagrant ssh
sudo su
cd /opt/boshcpi/openstack-cpi-release
./build-image.sh
```