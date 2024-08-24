package methods

import (
	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
)

type DeleteDiskMethod struct{}

func NewDeleteDiskMethod() DeleteDiskMethod {
	return DeleteDiskMethod{}
}

func (a DeleteDiskMethod) DeleteDisk(diskCID apiv1.DiskCID) error {
	return nil
}
