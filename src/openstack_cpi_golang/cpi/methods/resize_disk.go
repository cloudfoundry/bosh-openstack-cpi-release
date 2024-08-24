package methods

import (
	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
)

type ResizeDiskMethod struct{}

func NewResizeDiskMethod() ResizeDiskMethod {
	return ResizeDiskMethod{}
}

func (r ResizeDiskMethod) ResizeDisk(cid apiv1.DiskCID, size int) error {
	return nil
}
