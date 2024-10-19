package image

import (
	"fmt"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
)

//counterfeiter:generate . HeavyStemcellCreator
type HeavyStemcellCreator interface {
	Create(imageService ImageService, cloudProps properties.CreateStemcell, imagePath string) (string, error)
}

type heavyStemcellCreator struct {
	config config.OpenstackConfig
}

func NewHeavyStemcellCreator(
	config config.OpenstackConfig,
) heavyStemcellCreator {
	return heavyStemcellCreator{
		config: config,
	}
}

func (h heavyStemcellCreator) Create(imageService ImageService, cloudProps properties.CreateStemcell, rootImagePath string) (string, error) {
	imageID, err := imageService.CreateImage(cloudProps, h.config)
	if err != nil {
		return "", fmt.Errorf("failed to create image: %w", err)
	}

	err = imageService.UploadImage(imageID, rootImagePath)
	if err != nil {
		return "", fmt.Errorf("failed to upload root image: %w", err)
	}

	return imageID, nil
}
