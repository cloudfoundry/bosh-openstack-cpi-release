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
