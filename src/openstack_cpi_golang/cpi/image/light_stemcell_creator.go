package image

import (
	"fmt"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
)

//counterfeiter:generate . LightStemcellCreator
type LightStemcellCreator interface {
	Create(
		imageService ImageService,
		cloudProps properties.CreateStemcell,
	) (string, error)
}

type lightStemcellCreator struct {
	config config.OpenstackConfig
}

func NewLightStemcellCreator(
	config config.OpenstackConfig,
) lightStemcellCreator {
	return lightStemcellCreator{
		config: config,
	}
}

func (h lightStemcellCreator) Create(
	imageService ImageService,
	cloudProps properties.CreateStemcell,
) (string, error) {
	imageID, err := imageService.GetImage(cloudProps.ImageID)
	if err != nil {
		if err != nil {
			return "", fmt.Errorf("failed to retrieve image: %w", err)
		}
	}

	return imageID, nil
}
