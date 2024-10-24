package loadbalancer

import (
	"fmt"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/openstack"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
)

//counterfeiter:generate . LoadbalancerServiceBuilder
type LoadbalancerServiceBuilder interface {
	Build() (LoadbalancerService, error)
}

type loadbalancerServiceBuilder struct {
	openstackService openstack.OpenstackService
	cpiConfig        config.CpiConfig
	logger           utils.Logger
}

func NewLoadbalancerServiceBuilder(openstackService openstack.OpenstackService, cpiConfig config.CpiConfig, logger utils.Logger) loadbalancerServiceBuilder {
	return loadbalancerServiceBuilder{
		openstackService: openstackService,
		cpiConfig:        cpiConfig,
		logger:           logger,
	}
}

func (b loadbalancerServiceBuilder) Build() (LoadbalancerService, error) {
	serviceClient, err := b.openstackService.LoadbalancerV2(b.cpiConfig.OpenStackConfig())
	if err != nil {
		return nil, fmt.Errorf("failed to retrieve loadbalancer service client: %w", err)
	}

	return NewLoadbalancerService(
		utils.NewServiceClients(serviceClient, b.cpiConfig, b.logger),
		NewLoadbalancerFacade(),
		b.logger,
	), nil
}
