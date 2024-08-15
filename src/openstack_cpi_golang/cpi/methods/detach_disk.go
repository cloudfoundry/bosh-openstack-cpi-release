package methods

import (
	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
)

type DetachDiskMethod struct{}

func NewDetachDiskMethod() DetachDiskMethod {
	return DetachDiskMethod{}
}

func (a DetachDiskMethod) DetachDisk(vmCID apiv1.VMCID, diskCID apiv1.DiskCID) error {
	return nil
}
