package image

import (
	"fmt"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/openstack"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
)

//counterfeiter:generate . ImageServiceBuilder
type ImageServiceBuilder interface {
	Build() (ImageService, error)
}

type imageServiceBuilder struct {
	openstackService openstack.OpenstackService
	cpiConfig        config.CpiConfig
	logger           utils.Logger
}

func NewImageServiceBuilder(openstackService openstack.OpenstackService, cpiConfig config.CpiConfig, logger utils.Logger) imageServiceBuilder {
	return imageServiceBuilder{
		openstackService: openstackService,
		cpiConfig:        cpiConfig,
		logger:           logger,
	}
}

func (b imageServiceBuilder) Build() (ImageService, error) {
	serviceClient, err := b.openstackService.ImageServiceV2(b.cpiConfig.OpenStackConfig())
	if err != nil {
		return nil, fmt.Errorf("failed to retrieve image service client: %w", err)
	}

	return NewImageService(
		utils.NewServiceClients(serviceClient, b.cpiConfig, b.logger),
		NewImageFacade(),
		NewHttpClient(),
		b.logger,
	), nil
}
