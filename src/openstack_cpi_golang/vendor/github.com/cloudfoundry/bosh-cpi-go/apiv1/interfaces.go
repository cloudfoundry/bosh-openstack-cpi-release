package apiv1

type CPIFactory interface {
	New(CallContext) (CPI, error)
}

type CallContext interface {
	As(interface{}) error
}

type CPI interface {
	Info() (Info, error)
	CPIV1
	CPIV2Additions
}

type CPIV1 interface {
	StemcellsV1
	VMsV1
	DisksV1
	SnapshotsV1
}

type CPIV2Additions interface {
	VMsV2Additions
	DisksV2Additions
}

type Info struct {
	APIVersion      int      `json:"api_version"` // filled automatically
	StemcellFormats []string `json:"stemcell_formats"`
}
