package openstack

import (
	"fmt"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/gophercloud/gophercloud"
)

//counterfeiter:generate . OpenstackService
type OpenstackService interface {
	ComputeServiceV2(config config.OpenstackConfig) (*gophercloud.ServiceClient, error)
	LoadbalancerV2(config config.OpenstackConfig) (*gophercloud.ServiceClient, error)
	NetworkServiceV2(config config.OpenstackConfig) (*gophercloud.ServiceClient, error)
	ImageServiceV2(config config.OpenstackConfig) (*gophercloud.ServiceClient, error)
	BlockStorageV3(config config.OpenstackConfig) (*gophercloud.ServiceClient, error)
}

type openstackService struct {
	openstackFacade OpenstackFacade
	envVar          utils.EnvVar
}

func NewOpenstackService(openstackFacade OpenstackFacade, envVar utils.EnvVar) OpenstackService {
	return openstackService{
		openstackFacade: openstackFacade,
		envVar:          envVar,
	}
}

func (c openstackService) ComputeServiceV2(config config.OpenstackConfig) (*gophercloud.ServiceClient, error) {
	authenticatedClient, err := c.openstackFacade.AuthenticatedClient(config.AuthOptions())
	if err != nil {
		return nil, fmt.Errorf("failed to authenticate: %w", err)
	}

	return c.openstackFacade.NewComputeV2(authenticatedClient, c.endpointOpts())
}

func (c openstackService) LoadbalancerV2(config config.OpenstackConfig) (*gophercloud.ServiceClient, error) {
	authenticatedClient, err := c.openstackFacade.AuthenticatedClient(config.AuthOptions())
	if err != nil {
		return nil, fmt.Errorf("failed to authenticate: %w", err)
	}

	return c.openstackFacade.NewLoadBalancerV2(authenticatedClient, c.endpointOpts())
}

func (c openstackService) NetworkServiceV2(config config.OpenstackConfig) (*gophercloud.ServiceClient, error) {
	authenticatedClient, err := c.openstackFacade.AuthenticatedClient(config.AuthOptions())
	if err != nil {
		return nil, fmt.Errorf("failed to authenticate: %w", err)
	}

	return c.openstackFacade.NewNetworkV2(authenticatedClient, c.endpointOpts())
}

func (c openstackService) ImageServiceV2(config config.OpenstackConfig) (*gophercloud.ServiceClient, error) {
	authenticatedClient, err := c.openstackFacade.AuthenticatedClient(config.AuthOptions())
	if err != nil {
		return nil, fmt.Errorf("failed to authenticate: %w", err)
	}

	return c.openstackFacade.NewImageServiceV2(authenticatedClient, c.endpointOpts())
}

func (c openstackService) BlockStorageV3(config config.OpenstackConfig) (*gophercloud.ServiceClient, error) {
	authenticatedClient, err := c.openstackFacade.AuthenticatedClient(config.AuthOptions())
	if err != nil {
		return nil, fmt.Errorf("failed to authenticate: %w", err)
	}

	return c.openstackFacade.NewBlockStorageV3(authenticatedClient, c.endpointOpts())
}

func (c openstackService) endpointOpts() gophercloud.EndpointOpts {
	return gophercloud.EndpointOpts{
		Region: c.envVar.Get("OS_REGION_NAME"),
	}
}
