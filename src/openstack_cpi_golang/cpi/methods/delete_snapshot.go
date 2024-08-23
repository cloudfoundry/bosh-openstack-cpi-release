package methods

import (
	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
)

type DeleteSnapshotMethod struct{}

func NewDeleteSnapshotMethod() DeleteSnapshotMethod {
	return DeleteSnapshotMethod{}
}

func (s DeleteSnapshotMethod) DeleteSnapshot(cid apiv1.SnapshotCID) error {
	return nil
}
