package methods

import (
	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
)

type HasVMMethod struct{}

func NewHasVMMethod() HasVMMethod {
	return HasVMMethod{}
}

func (a HasVMMethod) HasVM(vmCID apiv1.VMCID) (bool, error) {
	return false, nil
}
