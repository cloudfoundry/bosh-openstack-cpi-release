package apiv1

import (
	"fmt"
)

type StemcellAPIVersion struct {
	ctx CallContext
}

type stemcellAPIVersionRoot struct {
	VM stemcellAPIVersionVM `json:"vm"`
}

type stemcellAPIVersionVM struct {
	Stemcell stemcellAPIVersionStemcell `json:"stemcell"`
}

type stemcellAPIVersionStemcell struct {
	APIVersion int `json:"api_version"`
}

func NewStemcellAPIVersion(ctx CallContext) StemcellAPIVersion {
	return StemcellAPIVersion{ctx}
}

func (s StemcellAPIVersion) Value() (int, error) {
	var root stemcellAPIVersionRoot

	err := s.ctx.As(&root)
	if err != nil {
		return 0, fmt.Errorf("Expected to unmarshal stemcell API version: %s", err) //nolint:staticcheck
	}

	return root.VM.Stemcell.APIVersion, nil
}
