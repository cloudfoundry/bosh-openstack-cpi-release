package methods

import (
	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
)

type SetDiskMetadataMethod struct{}

func NewSetDiskMetadataMethod() SetDiskMetadataMethod {
	return SetDiskMetadataMethod{}
}

func (s SetDiskMetadataMethod) SetDiskMetadata(cid apiv1.DiskCID, meta apiv1.DiskMeta) error {
	return nil
}
