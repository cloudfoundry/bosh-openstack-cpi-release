package loadbalancer

import (
	"errors"
	"fmt"
	"time"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/gophercloud/gophercloud"
	"github.com/gophercloud/gophercloud/openstack/loadbalancer/v2/loadbalancers"
	"github.com/gophercloud/gophercloud/openstack/loadbalancer/v2/pools"
)

var LoadbalancerServicePollingInterval = 10 * time.Second

//counterfeiter:generate . LoadbalancerService
type LoadbalancerService interface {
	GetPool(poolName string) (pools.Pool, error)

	CreatePoolMember(pool pools.Pool, ip string, poolProperties properties.LoadbalancerPool, subnetID string, timeout int) (*pools.Member, error)

	DeletePoolMember(poolID string, memberID string, timeout int) error
}

type loadbalancerService struct {
	serviceClients     utils.ServiceClients
	loadbalancerFacade LoadbalancerFacade
	logger             utils.Logger
}

func NewLoadbalancerService(
	serviceClients utils.ServiceClients,
	loadbalancerFacade LoadbalancerFacade,
	logger utils.Logger,
) loadbalancerService {
	return loadbalancerService{
		serviceClients:     serviceClients,
		loadbalancerFacade: loadbalancerFacade,
		logger:             logger,
	}
}

func (l loadbalancerService) GetPool(poolName string) (pools.Pool, error) {
	listOpts := pools.ListOpts{
		Name: poolName,
	}

	page, err := l.loadbalancerFacade.ListPools(l.serviceClients.RetryableServiceClient, listOpts)
	if err != nil {
		return pools.Pool{}, fmt.Errorf("failed to list loadbalancer pools: %w", err)
	}

	extractedPools, err := l.loadbalancerFacade.ExtractPools(page)
	if err != nil {
		return pools.Pool{}, fmt.Errorf("failed to extract loadbalancer pool pages: %w", err)
	}

	if len(extractedPools) == 0 {
		return pools.Pool{}, fmt.Errorf("loadbalancer pool '%s' does not exist", poolName)
	}

	if len(extractedPools) > 1 {
		return pools.Pool{}, fmt.Errorf("found more than one loadbalancer pool with name '%s'. Make sure to use unique naming", poolName)
	}

	return extractedPools[0], nil
}

func (l loadbalancerService) CreatePoolMember(pool pools.Pool, ip string, poolProperties properties.LoadbalancerPool, subnetID string, stateTimeOut int) (*pools.Member, error) {
	var err error
	var errDefault409 gophercloud.ErrDefault409
	var poolMember *pools.Member

	createMemberOpts := pools.CreateMemberOpts{
		Address:      ip,
		ProtocolPort: poolProperties.ProtocolPort,
		SubnetID:     subnetID,
	}

	if poolProperties.MonitoringPort != nil {
		createMemberOpts.MonitorPort = poolProperties.MonitoringPort
	}

	loadbalancerId, err := l.getLoadbalancerId(pool)
	if err != nil {
		return nil, fmt.Errorf("failed to get loadbalancer ID: %w", err)
	}

	timeoutDuration := time.Duration(stateTimeOut) * time.Second
	createPoolMemberTimeoutTimer := time.NewTimer(timeoutDuration)
	attempts := 0

	for poolMember == nil {
		select {
		case <-createPoolMemberTimeoutTimer.C:
			return nil, fmt.Errorf("timeout after %v attempts while creating pool membership with IP '%s' in pool '%s'", attempts, ip, pool.ID)
		default:
			poolMember, err = l.createPoolMember(loadbalancerId, pool.ID, createMemberOpts, timeoutDuration)
			if err != nil {
				if errors.As(err, &errDefault409) {
					// If there is a conflict, try to find if the pool member already exists with the same IP and Port
					poolMember := l.getPoolMember(pool.ID, createMemberOpts)
					if poolMember != nil {
						l.logger.Info("loadbalancer_service", fmt.Sprintf("SKIPPING creation: pool membership with pool id '%s', ip '%s', and port '%v' already exists", pool.ID, ip, poolProperties.ProtocolPort))
						return poolMember, nil
					} else {
						attempts++
						l.logger.Warn("loadbalancer_service", fmt.Sprintf("creating pool membership with IP '%s' in pool '%s' failed in attempt number '%v' with error: %s", ip, pool.ID, attempts, err.Error()))
					}
				} else {
					return nil, err
				}
			}
		}
	}

	_, err = l.waitForLoadbalancerToBecomeActive(loadbalancerId, timeoutDuration)
	if err != nil {
		return nil, fmt.Errorf("failed while waiting for loadbalancer '%s' to become active: %w", loadbalancerId, err)
	}

	return poolMember, nil
}

func (l loadbalancerService) DeletePoolMember(poolID string, memberID string, stateTimeOut int) error {
	var err error
	var errDefault409 gophercloud.ErrDefault409
	var errDefault404 gophercloud.ErrDefault404

	var isDeleted bool

	pool, err := l.loadbalancerFacade.GetPool(l.serviceClients.RetryableServiceClient, poolID)
	if err != nil {
		return fmt.Errorf("failed to get pool with ID '%s': %w", poolID, err)
	}

	loadbalancerId, err := l.getLoadbalancerId(*pool)
	if err != nil {
		return fmt.Errorf("failed to get loadbalancer ID: %w", err)
	}

	timeoutDuration := time.Duration(stateTimeOut) * time.Second
	deletePoolMemberTimeoutTimer := time.NewTimer(timeoutDuration)
	attempts := 0

	for !isDeleted {
		select {
		case <-deletePoolMemberTimeoutTimer.C:
			return fmt.Errorf("timeout after %v attempts while deleting pool membership with ID '%s' in pool '%s'", attempts, memberID, poolID)
		default:
			err = l.deletePoolMember(loadbalancerId, poolID, memberID, timeoutDuration)
			if err != nil {
				if errors.As(err, &errDefault409) {
					attempts++
					l.logger.Warn("loadbalancer_service", fmt.Sprintf("deleting pool membership with ID '%s' in pool '%s' failed in attempt number '%v' with error: %s", memberID, poolID, attempts, err.Error()))
				} else if errors.As(err, &errDefault404) {
					l.logger.Info("loadbalancer_service", fmt.Sprintf("SKIPPING deletion: pool member with id '%s' in pool '%s' is not found", memberID, poolID))
					return nil
				} else {
					return err
				}
			}
			isDeleted = true
			l.logger.Info("loadbalancer_service", fmt.Sprintf("Deleted pool member with id '%s' from pool '%s'", memberID, poolID))
		}
	}

	_, err = l.waitForLoadbalancerToBecomeActive(loadbalancerId, timeoutDuration)
	if err != nil {
		return fmt.Errorf("failed while waiting for loadbalancer '%s' to become active: %w", loadbalancerId, err)
	}

	return nil
}

func (l loadbalancerService) createPoolMember(loadbalancerID string, poolID string, createMemberOpts pools.CreateMemberOpts, timeout time.Duration) (*pools.Member, error) {
	_, err := l.waitForLoadbalancerToBecomeActive(loadbalancerID, timeout)
	if err != nil {
		return nil, fmt.Errorf("failed while waiting for loadbalancer to become active: %w", err)
	}

	member, err := l.loadbalancerFacade.CreatePoolMember(l.serviceClients.ServiceClient, poolID, createMemberOpts)
	if err != nil {
		return nil, fmt.Errorf("failed to create pool member: %w", err)
	}

	return member, nil
}

func (l loadbalancerService) deletePoolMember(loadbalancerID string, poolID string, memberID string, timeout time.Duration) error {
	_, err := l.waitForLoadbalancerToBecomeActive(loadbalancerID, timeout)
	if err != nil {
		return fmt.Errorf("failed while waiting for loadbalancer to become active: %w", err)
	}

	err = l.loadbalancerFacade.DeletePoolMember(l.serviceClients.RetryableServiceClient, poolID, memberID)
	if err != nil {
		return fmt.Errorf("failed to delete pool member: %w", err)
	}

	return nil
}

func (l loadbalancerService) getPoolMember(poolID string, poolMemberOpts pools.CreateMemberOpts) *pools.Member {
	var result *pools.Member

	listOpts := pools.ListMembersOpts{
		Address:      poolMemberOpts.Address,
		ProtocolPort: poolMemberOpts.ProtocolPort,
	}

	pages, err := l.loadbalancerFacade.ListPoolMembers(l.serviceClients.RetryableServiceClient, poolID, listOpts)
	if err != nil {
		return nil
	}

	extractedPoolMembers, err := l.loadbalancerFacade.ExtractPoolMembers(pages)
	if err != nil {
		return nil
	}

	if len(extractedPoolMembers) == 0 {
		return nil
	}

	for _, poolMember := range extractedPoolMembers {
		if poolMember.SubnetID == poolMemberOpts.SubnetID {
			if poolMemberOpts.MonitorPort != nil {
				if poolMember.MonitorPort == *poolMemberOpts.MonitorPort {
					result = &poolMember
					break
				} else {
					continue
				}
			}

			result = &poolMember
			break
		}
	}

	return result
}

func (l loadbalancerService) getLoadbalancerId(pool pools.Pool) (string, error) {
	loadbalancerList := pool.Loadbalancers

	if len(loadbalancerList) == 0 {
		loadbalancerListeners := pool.Listeners

		if len(loadbalancerListeners) == 0 {
			return "", fmt.Errorf("no load balancers or listeners associated with pool '%s'", pool.ID)
		} else if len(loadbalancerListeners) > 1 {
			return "", fmt.Errorf("more than one listener is associated with pool '%s'. It is not possible "+
				"to verify the status of the load balancer responsible for the pool membership", pool.ID)
		} else {
			listener, err := l.loadbalancerFacade.GetListener(l.serviceClients.RetryableServiceClient, loadbalancerListeners[0].ID)
			if err != nil || listener == nil {
				return "", fmt.Errorf("failed to retrieve listener '%s': %w", loadbalancerListeners[0].ID, err)
			}

			for _, lb := range listener.Loadbalancers {
				loadbalancerList = append(loadbalancerList, pools.LoadBalancerID{ID: lb.ID})
			}
		}
	}

	if len(loadbalancerList) == 0 {
		return "", fmt.Errorf("no load balancers associated with pool '%s'", pool.ID)
	} else if len(loadbalancerList) > 1 {
		return "", fmt.Errorf("more than one load balancer is associated with pool '%s'. It is not possible "+
			"to verify the status of the load balancer responsible for the pool membership", pool.ID)
	}

	return loadbalancerList[0].ID, nil
}

func (l loadbalancerService) waitForLoadbalancerToBecomeActive(loadbalancerID string, timeout time.Duration) (*loadbalancers.LoadBalancer, error) {
	timeoutTimer := time.NewTimer(timeout)

	for {
		select {
		case <-timeoutTimer.C:
			return nil, fmt.Errorf("timeout while waiting for loadbalancer '%s' to become active", loadbalancerID)
		default:
			loadbalancer, err := l.loadbalancerFacade.GetLoadbalancer(l.serviceClients.RetryableServiceClient, loadbalancerID)
			if err != nil || loadbalancer == nil {
				return nil, fmt.Errorf("failed to retrieve loadbalancer '%s': %w", loadbalancerID, err)
			}

			switch loadbalancer.ProvisioningStatus {
			case "ACTIVE":
				return loadbalancer, nil
			case "ERROR":
				return nil, fmt.Errorf("loadbalancer status ended up in '%s' state", loadbalancer.ProvisioningStatus)
			default:
				time.Sleep(LoadbalancerServicePollingInterval)
				continue
			}
		}
	}
}
