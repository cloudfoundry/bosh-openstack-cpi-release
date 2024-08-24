package methods

import (
	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
)

type AttachDiskMethod struct {
}

func NewAttachDiskMethod() AttachDiskMethod {
	return AttachDiskMethod{}
}

func (a AttachDiskMethod) AttachDisk(vmCID apiv1.VMCID, diskCID apiv1.DiskCID) error {
	return nil
}

func (a AttachDiskMethod) AttachDiskV2(vmCID apiv1.VMCID, diskCID apiv1.DiskCID) (apiv1.DiskHint, error) {
	return apiv1.DiskHint{}, nil
}
