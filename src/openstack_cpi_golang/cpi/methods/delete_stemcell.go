package methods

import (
	"fmt"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/image"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	boshlog "github.com/cloudfoundry/bosh-utils/logger"
)

type DeleteStemcellMethod struct {
	imageServiceBuilder image.ImageServiceBuilder
	logger              boshlog.Logger
	logTag              string
}

func NewDeleteStemcellMethod(
	serviceFactory image.ImageServiceBuilder,
	logger boshlog.Logger,
) DeleteStemcellMethod {
	return DeleteStemcellMethod{
		imageServiceBuilder: serviceFactory,
		logger:              logger,
		logTag:              "delete_stemcell",
	}
}

func (a DeleteStemcellMethod) DeleteStemcell(cid apiv1.StemcellCID) error {
	a.logger.Info(a.logTag, "Creating image service ...")
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
