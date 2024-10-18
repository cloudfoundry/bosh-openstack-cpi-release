package compute

import (
	"fmt"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/openstack"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
)

//counterfeiter:generate . ComputeServiceBuilder
type ComputeServiceBuilder interface {
	Build() (ComputeService, error)
}

type computeServiceBuilder struct {
	openstackService openstack.OpenstackService
	cpiConfig        config.CpiConfig
	logger           utils.Logger
}

func NewComputeServiceBuilder(openstackService openstack.OpenstackService, cpiConfig config.CpiConfig, logger utils.Logger) computeServiceBuilder {
	return computeServiceBuilder{
		openstackService: openstackService,
		cpiConfig:        cpiConfig,
		logger:           logger,
	}
}

func (b computeServiceBuilder) Build() (ComputeService, error) {
	serviceClient, err := b.openstackService.ComputeServiceV2(b.cpiConfig.OpenStackConfig())
	if err != nil {
		return nil, fmt.Errorf("failed to retrieve compute service client: %w", err)
	}

	serviceClients := utils.NewServiceClients(serviceClient, b.cpiConfig, b.logger)
	computeFacade := NewComputeFacade()
	return NewComputeService(
		serviceClients,
		computeFacade,
		NewFlavorResolver(serviceClients, computeFacade),
		NewVolumeConfigurator(),
		NewAvailabilityZoneProvider(),
		b.logger,
	), nil
}
