package methods

import (
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/extensions/volumeattach"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/servers"
)

func (a AttachDiskMethod) GetFirstDeviceNameLetterWrapper(computeService compute.ComputeService, server servers.Server) (rune, error) {
	return a.getFirstDeviceNameLetter(computeService, server)
}

func (a AttachDiskMethod) GetMountPoint(computeService compute.ComputeService, server servers.Server) (string, error) {
	return a.getMountPoint(computeService, server)
}

func (a AttachDiskMethod) GetDeviceChar(inspectChar rune, attachments []volumeattach.VolumeAttachment) (rune, error) {
	return a.getDeviceChar(inspectChar, attachments)
}
