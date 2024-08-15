package methods

import (
	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
)

type CreateDiskMethod struct{}

func NewCreateDiskMethod() CreateDiskMethod {
	return CreateDiskMethod{}
}

func (a CreateDiskMethod) CreateDisk(size int, props apiv1.DiskCloudProps, vmCID *apiv1.VMCID) (apiv1.DiskCID, error) {
	return apiv1.DiskCID{}, nil
}
