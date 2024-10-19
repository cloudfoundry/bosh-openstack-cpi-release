package openstack

import (
	"github.com/gophercloud/gophercloud"
	"github.com/gophercloud/gophercloud/openstack"
)

//counterfeiter:generate . OpenstackFacade
type OpenstackFacade interface {
	NewComputeV2(client *gophercloud.ProviderClient, eo gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error)

	NewLoadBalancerV2(client *gophercloud.ProviderClient, endpointOpts gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error)

	NewNetworkV2(client *gophercloud.ProviderClient, eo gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error)

	NewImageServiceV2(client *gophercloud.ProviderClient, eo gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error)

	NewBlockStorageV3(client *gophercloud.ProviderClient, eo gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error)

	AuthenticatedClient(options gophercloud.AuthOptions) (*gophercloud.ProviderClient, error)
}

type openstackFacade struct{}

func NewOpenstackFacade() OpenstackFacade {
	return openstackFacade{}
}

func (c openstackFacade) NewComputeV2(client *gophercloud.ProviderClient, endpointOpts gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error) {
	return openstack.NewComputeV2(client, endpointOpts)
}

func (c openstackFacade) NewLoadBalancerV2(client *gophercloud.ProviderClient, endpointOpts gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error) {
	return openstack.NewLoadBalancerV2(client, endpointOpts)
}

func (c openstackFacade) NewNetworkV2(client *gophercloud.ProviderClient, endpointOpts gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error) {
	return openstack.NewNetworkV2(client, endpointOpts)
}

func (c openstackFacade) NewImageServiceV2(client *gophercloud.ProviderClient, endpointOpts gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error) {
	return openstack.NewImageServiceV2(client, endpointOpts)
}

func (c openstackFacade) NewBlockStorageV3(client *gophercloud.ProviderClient, endpointOpts gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error) {
	return openstack.NewBlockStorageV3(client, endpointOpts)
}

func (c openstackFacade) AuthenticatedClient(options gophercloud.AuthOptions) (*gophercloud.ProviderClient, error) {
	return openstack.AuthenticatedClient(options)
}
