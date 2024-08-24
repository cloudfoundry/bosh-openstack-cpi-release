package apiv1

type SnapshotsV1 interface {
	SnapshotDisk(DiskCID, DiskMeta) (SnapshotCID, error)
	DeleteSnapshot(SnapshotCID) error
}

type SnapshotCID struct {
	cloudID
}

func NewSnapshotCID(cid string) SnapshotCID {
	if cid == "" {
		panic("Internal inconsistency: Snapshot CID must not be empty")
	}
	return SnapshotCID{cloudID{cid}}
}
