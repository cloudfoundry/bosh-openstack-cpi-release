package apiv1

type StemcellsV1 interface {
	CreateStemcell(string, StemcellCloudProps) (StemcellCID, error)
	DeleteStemcell(StemcellCID) error
}

type StemcellCloudProps interface {
	As(interface{}) error
}

type StemcellCID struct {
	cloudID
}

func NewStemcellCID(cid string) StemcellCID {
	if cid == "" {
		panic("Internal incosistency: Stemcell CID must not be empty")
	}
	return StemcellCID{cloudID{cid}}
}
