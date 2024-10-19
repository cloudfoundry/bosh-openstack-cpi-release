package volume

import (
	"fmt"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/openstack"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
)

//counterfeiter:generate . VolumeServiceBuilder
type VolumeServiceBuilder interface {
	Build() (VolumeService, error)
}

type volumeServiceBuilder struct {
	openstackService openstack.OpenstackService
	cpiConfig        config.CpiConfig
	logger           utils.Logger
}

func NewVolumeServiceBuilder(openstackService openstack.OpenstackService, cpiConfig config.CpiConfig, logger utils.Logger) volumeServiceBuilder {
	return volumeServiceBuilder{
		openstackService: openstackService,
		cpiConfig:        cpiConfig,
		logger:           logger,
	}
}

func (v volumeServiceBuilder) Build() (VolumeService, error) {
	serviceClient, err := v.openstackService.BlockStorageV3(v.cpiConfig.OpenStackConfig())
	if err != nil {
		return nil, fmt.Errorf("failed to retrieve volume service client: %w", err)
	}

	serviceClients := utils.NewServiceClients(serviceClient, v.cpiConfig, v.logger)
	volumeFacade := NewVolumeFacade()
	return NewVolumeService(serviceClients, volumeFacade), nil
}
