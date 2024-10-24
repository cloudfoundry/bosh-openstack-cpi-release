package network

import (
	"fmt"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/openstack"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
)

//counterfeiter:generate . NetworkServiceBuilder
type NetworkServiceBuilder interface {
	Build() (NetworkService, error)
}

type networkServiceBuilder struct {
	openstackService openstack.OpenstackService
	cpiConfig        config.CpiConfig
	logger           utils.Logger
}

func NewNetworkServiceBuilder(openstackService openstack.OpenstackService, cpiConfig config.CpiConfig, logger utils.Logger) networkServiceBuilder {
	return networkServiceBuilder{
		openstackService: openstackService,
		cpiConfig:        cpiConfig,
		logger:           logger,
	}
}

func (b networkServiceBuilder) Build() (NetworkService, error) {
	serviceClient, err := b.openstackService.NetworkServiceV2(b.cpiConfig.OpenStackConfig())
	if err != nil {
		return nil, fmt.Errorf("failed to retrieve network service client: %w", err)
	}

	return NewNetworkService(
		utils.NewServiceClients(serviceClient, b.cpiConfig, b.logger),
		NewNetworkingFacade(),
		b.logger,
	), nil
}
