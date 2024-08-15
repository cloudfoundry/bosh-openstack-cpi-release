package methods

import (
	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
)

type HasDiskMethod struct{}

func NewHasDiskMethod() HasDiskMethod {
	return HasDiskMethod{}
}

func (a HasDiskMethod) HasDisk(cid apiv1.DiskCID) (bool, error) {
	return false, nil
}
