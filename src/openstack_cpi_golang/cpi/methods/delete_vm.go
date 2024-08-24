package methods

import (
	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
)

type DeleteVMMethod struct{}

func NewDeleteVMMethod() DeleteVMMethod {
	return DeleteVMMethod{}
}

func (a DeleteVMMethod) DeleteVM(cid apiv1.VMCID) error {
	return nil
}
