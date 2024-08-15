package methods

import (
	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
)

type SetVMMetadataMethod struct{}

func NewSetVMMetadataMethod() SetVMMetadataMethod {
	return SetVMMetadataMethod{}
}

func (s SetVMMetadataMethod) SetVMMetadata(vmCID apiv1.VMCID, meta apiv1.VMMeta) error {
	return nil
}
