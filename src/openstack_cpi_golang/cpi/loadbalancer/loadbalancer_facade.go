package loadbalancer

import (
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/gophercloud/gophercloud/openstack/loadbalancer/v2/listeners"
	"github.com/gophercloud/gophercloud/openstack/loadbalancer/v2/loadbalancers"
	"github.com/gophercloud/gophercloud/openstack/loadbalancer/v2/pools"
	"github.com/gophercloud/gophercloud/pagination"
)

//counterfeiter:generate . LoadbalancerFacade
type LoadbalancerFacade interface {
	GetLoadbalancer(client utils.RetryableServiceClient, loadbalancerID string) (*loadbalancers.LoadBalancer, error)

	GetListener(client utils.RetryableServiceClient, listenerID string) (*listeners.Listener, error)

	GetPool(client utils.RetryableServiceClient, poolID string) (*pools.Pool, error)

	ListPools(client utils.RetryableServiceClient, listOpts pools.ListOpts) (pagination.Page, error)

	ExtractPools(allPages pagination.Page) ([]pools.Pool, error)

	ListPoolMembers(client utils.RetryableServiceClient, poolID string, opts pools.ListMembersOpts) (pagination.Page, error)

	ExtractPoolMembers(allPages pagination.Page) ([]pools.Member, error)

	CreatePoolMember(client utils.ServiceClient, poolID string, opts pools.CreateMemberOpts) (*pools.Member, error)

	DeletePoolMember(client utils.RetryableServiceClient, poolID string, memberID string) error
}

type loadbalancerFacade struct {
}

func NewLoadbalancerFacade() loadbalancerFacade {
	return loadbalancerFacade{}
}

func (l loadbalancerFacade) GetLoadbalancer(client utils.RetryableServiceClient, loadbalancerID string) (*loadbalancers.LoadBalancer, error) {
	return loadbalancers.Get(client, loadbalancerID).Extract()
}

func (l loadbalancerFacade) GetListener(client utils.RetryableServiceClient, listenerID string) (*listeners.Listener, error) {
	return listeners.Get(client, listenerID).Extract()
}

func (l loadbalancerFacade) GetPool(client utils.RetryableServiceClient, poolID string) (*pools.Pool, error) {
	return pools.Get(client, poolID).Extract()
}

func (l loadbalancerFacade) ListPools(client utils.RetryableServiceClient, listOpts pools.ListOpts) (pagination.Page, error) {
	return pools.List(client, listOpts).AllPages()
}

func (l loadbalancerFacade) ExtractPools(allPages pagination.Page) ([]pools.Pool, error) {
	return pools.ExtractPools(allPages)
}

func (l loadbalancerFacade) ListPoolMembers(client utils.RetryableServiceClient, poolID string, opts pools.ListMembersOpts) (pagination.Page, error) {
	return pools.ListMembers(client, poolID, opts).AllPages()
}

func (l loadbalancerFacade) ExtractPoolMembers(allPages pagination.Page) ([]pools.Member, error) {
	return pools.ExtractMembers(allPages)
}

func (l loadbalancerFacade) CreatePoolMember(client utils.ServiceClient, poolID string, opts pools.CreateMemberOpts) (*pools.Member, error) {
	return pools.CreateMember(client, poolID, opts).Extract()
}

func (l loadbalancerFacade) DeletePoolMember(client utils.RetryableServiceClient, poolID string, memberID string) error {
	return pools.DeleteMember(client, poolID, memberID).ExtractErr()
}
