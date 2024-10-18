package methods

import (
	"fmt"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/image"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
)

type DeleteStemcellMethod struct {
	imageServiceBuilder image.ImageServiceBuilder
	logger              utils.Logger
}

func NewDeleteStemcellMethod(
	serviceFactory image.ImageServiceBuilder,
	logger utils.Logger,
) DeleteStemcellMethod {
	return DeleteStemcellMethod{
		imageServiceBuilder: serviceFactory,
		logger:              logger,
	}
}

func (a DeleteStemcellMethod) DeleteStemcell(cid apiv1.StemcellCID) error {
	a.logger.Info("delete_stemcell", "Creating image service ...")
	imageService, err := a.imageServiceBuilder.Build()
	if err != nil {
		return fmt.Errorf("failed to create image service: %w", err)
	}

	deletionError := imageService.DeleteImage(cid.AsString())

	if deletionError != nil {
		return fmt.Errorf("failed to delete stemcell with cid %s due to the following: %w", cid.AsString(), deletionError)
	}
	return nil
}
