package methods

import (
	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
)

type DeleteStemcellMethod struct{}

func NewDeleteStemcellMethod() DeleteStemcellMethod {
	return DeleteStemcellMethod{}
}

func (a DeleteStemcellMethod) DeleteStemcell(cid apiv1.StemcellCID) error {
	return nil
}
