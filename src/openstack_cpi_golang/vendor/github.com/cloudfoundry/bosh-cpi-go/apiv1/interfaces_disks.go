package apiv1

type DisksV1 interface {
	CreateDisk(int, DiskCloudProps, *VMCID) (DiskCID, error)
	DeleteDisk(DiskCID) error

	AttachDisk(VMCID, DiskCID) error
	DetachDisk(VMCID, DiskCID) error
	SetDiskMetadata(DiskCID, DiskMeta) error

	HasDisk(DiskCID) (bool, error)
	ResizeDisk(DiskCID, int) error
}

type DisksV2Additions interface {
	AttachDiskV2(VMCID, DiskCID) (DiskHint, error)
}

// DiskUpdater is an opt-in CPI capability for the BOSH CPI v2 `update_disk`
// method. It returns the CID the Director should use going forward: the
// original CID for in-place updates, or a new CID if the disk was replaced.
type DiskUpdater interface {
	UpdateDisk(DiskCID, int, DiskCloudProps) (DiskCID, error)
}

type DiskCloudProps interface {
	As(interface{}) error
	_final() // interface unimplementable from outside
}

type DiskCID struct {
	cloudID
}

type DiskMeta struct {
	cloudKVs
}

func NewDiskCID(cid string) DiskCID {
	if cid == "" {
		panic("Internal inconsistency: Disk CID must not be empty")
	}
	return DiskCID{cloudID{cid}}
}

func NewDiskMeta(meta map[string]interface{}) DiskMeta {
	return DiskMeta{cloudKVs{meta}}
}
