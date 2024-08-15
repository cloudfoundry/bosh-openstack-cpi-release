package methods

import (
	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
)

type GetDisksMethod struct{}

func NewGetDisksMethod() GetDisksMethod {
	return GetDisksMethod{}
}

func (a GetDisksMethod) GetDisks(cid apiv1.VMCID) ([]apiv1.DiskCID, error) {
	// todo implement
	return nil, nil
}
