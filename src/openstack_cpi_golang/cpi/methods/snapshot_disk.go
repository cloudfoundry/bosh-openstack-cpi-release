package methods

import "github.com/cloudfoundry/bosh-cpi-go/apiv1"

type SnapshotDiskMethod struct{}

func NewSnapshotDiskMethod() SnapshotDiskMethod {
	return SnapshotDiskMethod{}
}

func (s SnapshotDiskMethod) SnapshotDisk(cid apiv1.DiskCID, meta apiv1.DiskMeta) (apiv1.SnapshotCID, error) {
	return apiv1.SnapshotCID{}, nil
}
