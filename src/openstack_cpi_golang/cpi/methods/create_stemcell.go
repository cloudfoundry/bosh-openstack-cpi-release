package methods

import (
	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
)

type CreateStemcellMethod struct {
}

func NewCreateStemcellMethod() CreateStemcellMethod {
	return CreateStemcellMethod{}
}

func (a CreateStemcellMethod) CreateStemcell(
	imagePath string,
	props apiv1.StemcellCloudProps,
) (apiv1.StemcellCID, error) {
	return apiv1.StemcellCID{}, nil
}
