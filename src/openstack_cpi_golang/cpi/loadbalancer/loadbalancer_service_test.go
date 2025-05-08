package loadbalancer_test

import (
	"errors"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/loadbalancer"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/loadbalancer/loadbalancerfakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/mocks"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	"github.com/gophercloud/gophercloud"
	"github.com/gophercloud/gophercloud/openstack/loadbalancer/v2/listeners"
	"github.com/gophercloud/gophercloud/openstack/loadbalancer/v2/loadbalancers"
	"github.com/gophercloud/gophercloud/openstack/loadbalancer/v2/pools"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("LoadbalancerService", func() {
	var serviceClient gophercloud.ServiceClient
	var retryableServiceClient gophercloud.ServiceClient
	var serviceClients utils.ServiceClients
	var loadbalancerFacade loadbalancerfakes.FakeLoadbalancerFacade
	var logger utilsfakes.FakeLogger
	var poolsPage mocks.MockPage
	var mockPool pools.Pool
	var mockListener listeners.Listener
	var mockMember pools.Member
	var poolProps properties.LoadbalancerPool

	BeforeEach(func() {
		serviceClient = gophercloud.ServiceClient{}
		retryableServiceClient = gophercloud.ServiceClient{}
		serviceClients = utils.ServiceClients{ServiceClient: &serviceClient, RetryableServiceClient: &retryableServiceClient}
		loadbalancerFacade = loadbalancerfakes.FakeLoadbalancerFacade{}
		logger = utilsfakes.FakeLogger{}
		poolsPage = mocks.MockPage{}

		loadbalancer.LoadbalancerServicePollingInterval = 0

		monitoringPort := 5678
		poolProps = properties.LoadbalancerPool{
			Name:           "pool-name",
			ProtocolPort:   1234,
			MonitoringPort: &monitoringPort,
		}

		mockListener = listeners.Listener{
			ID:            "the-listener-id",
			Loadbalancers: []listeners.LoadBalancerID{{ID: "the-lb-id"}},
		}

		mockPool = pools.Pool{
			ID:            "pool-id",
			Name:          "pool-name",
			Loadbalancers: []pools.LoadBalancerID{{ID: "the-lb-id"}},
			Listeners:     []pools.ListenerID{{ID: "the-listener-id"}},
		}

		mockMember = pools.Member{
			ID:           "the-member-id",
			SubnetID:     "subnet-id",
			Address:      "1.1.1.1",
			ProtocolPort: 1234,
			MonitorPort:  5678,
		}

		loadbalancerFacade.GetPoolReturns(&mockPool, nil)

		loadbalancerFacade.GetListenerReturns(&mockListener, nil)

		loadbalancerFacade.ExtractPoolMembersReturns([]pools.Member{mockMember}, nil)
	})

	Context("GetPool", func() {
		BeforeEach(func() {
			loadbalancerFacade.ListPoolsReturns(poolsPage, nil)
			loadbalancerFacade.ExtractPoolsReturns([]pools.Pool{mockPool}, nil)
		})

		It("lists loadbalancer pools", func() {
			_, _ = loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger). //nolint:errcheck
															GetPool("pool-name")

			_, listOpts := loadbalancerFacade.ListPoolsArgsForCall(0)
			Expect(listOpts.Name).To(Equal("pool-name"))
		})

		It("returns an error if listing loadbalancer pools fails", func() {
			loadbalancerFacade.ListPoolsReturns(nil, errors.New("boom"))

			pool, err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				GetPool("pool-name")

			Expect(err.Error()).To(Equal("failed to list loadbalancer pools: boom"))
			Expect(pool).To(Equal(pools.Pool{}))
		})

		It("extracts loadbalancer pools", func() {
			_, _ = loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger). //nolint:errcheck
															GetPool("pool-name")

			Expect(loadbalancerFacade.ExtractPoolsArgsForCall(0)).To(Equal(poolsPage))
		})

		It("returns an error if extracting loadbalancer pools fails", func() {
			loadbalancerFacade.ExtractPoolsReturns(nil, errors.New("boom"))

			pool, err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				GetPool("pool-name")

			Expect(err.Error()).To(Equal("failed to extract loadbalancer pool pages: boom"))
			Expect(pool.ID).To(Equal(""))
		})

		It("returns an error if pools are empty", func() {
			loadbalancerFacade.ExtractPoolsReturns([]pools.Pool{}, nil)

			pool, err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				GetPool("pool-name")

			Expect(err.Error()).To(Equal("loadbalancer pool 'pool-name' does not exist"))
			Expect(pool.ID).To(Equal(""))
		})

		It("returns an error if multiple pools with same name exists", func() {
			loadbalancerFacade.ExtractPoolsReturns([]pools.Pool{{Name: "pool-name"}, {Name: "pool-name"}}, nil)

			pool, err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				GetPool("pool-name")

			Expect(err.Error()).To(Equal("found more than one loadbalancer pool with name 'pool-name'. Make sure to use unique naming"))
			Expect(pool.ID).To(Equal(""))
		})

		It("returns the pool ID", func() {
			pool, err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				GetPool("pool-name")

			Expect(err).To(Not(HaveOccurred()))
			Expect(pool.ID).To(Equal("pool-id"))
		})
	})

	Context("CreatePoolMember", func() {
		BeforeEach(func() {
			loadbalancerFacade.GetLoadbalancerReturns(&loadbalancers.LoadBalancer{ID: "the-lb-id", ProvisioningStatus: "ACTIVE"}, nil)
			loadbalancerFacade.CreatePoolMemberReturns(&mockMember, nil)
		})

		It("waits for the loadbalancer to become ACTIVE", func() {
			loadbalancerFacade.GetLoadbalancerReturnsOnCall(0, &loadbalancers.LoadBalancer{ID: "the-lb-id", ProvisioningStatus: "PENDING_UPDATE"}, nil)
			loadbalancerFacade.GetLoadbalancerReturnsOnCall(1, &loadbalancers.LoadBalancer{ID: "the-lb-id", ProvisioningStatus: "ACTIVE"}, nil)

			_, err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				CreatePoolMember(mockPool, "1.1.1.1", poolProps, "subnet-id", 1)

			retryableServiceClient, poolId := loadbalancerFacade.GetLoadbalancerArgsForCall(0)
			var utilsRetryableServiceClient utils.RetryableServiceClient
			Expect(retryableServiceClient).To(BeAssignableToTypeOf(utilsRetryableServiceClient))

			Expect(poolId).To(Equal("the-lb-id"))
			Expect(err).ToNot(HaveOccurred())
		})

		It("retrieves the loadbalancer via listeners", func() {
			mockPool.Loadbalancers = []pools.LoadBalancerID{}

			_, err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				CreatePoolMember(mockPool, "1.1.1.1", poolProps, "subnet-id", 1)

			retryableServiceClient, poolId := loadbalancerFacade.GetLoadbalancerArgsForCall(0)
			var utilsRetryableServiceClient utils.RetryableServiceClient
			Expect(retryableServiceClient).To(BeAssignableToTypeOf(utilsRetryableServiceClient))

			Expect(poolId).To(Equal("the-lb-id"))
			Expect(err).ToNot(HaveOccurred())
		})

		It("fails if no loadbalancers nor listeners are associated with pool", func() {
			mockPool.Loadbalancers = []pools.LoadBalancerID{}
			mockPool.Listeners = []pools.ListenerID{}

			poolMember, err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				CreatePoolMember(mockPool, "1.1.1.1", poolProps, "subnet-id", 1)

			Expect(err.Error()).To(ContainSubstring("no load balancers or listeners associated with pool 'pool-id'"))
			Expect(poolMember).To(BeNil())
		})

		It("fails if multiple listeners are associated with pool", func() {
			mockPool.Loadbalancers = []pools.LoadBalancerID{}
			mockPool.Listeners = append(mockPool.Listeners, []pools.ListenerID{{ID: "another-listener-id"}}...)

			poolMember, err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				CreatePoolMember(mockPool, "1.1.1.1", poolProps, "subnet-id", 1)

			Expect(err.Error()).To(ContainSubstring("more than one listener is associated with pool 'pool-id'"))
			Expect(poolMember).To(BeNil())
		})

		It("fails if multiple loadbalancers are associated with pool", func() {
			mockPool.Loadbalancers = append(mockPool.Loadbalancers, []pools.LoadBalancerID{{ID: "another-lb-id"}}...)

			poolMember, err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				CreatePoolMember(mockPool, "1.1.1.1", poolProps, "subnet-id", 1)

			Expect(err.Error()).To(ContainSubstring("more than one load balancer is associated with pool 'pool-id'"))
			Expect(poolMember).To(BeNil())
		})

		It("fails if retrieving a listener fails", func() {
			mockPool.Loadbalancers = []pools.LoadBalancerID{}

			loadbalancerFacade.GetListenerReturns(&listeners.Listener{}, errors.New("boom"))

			poolMember, err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				CreatePoolMember(mockPool, "1.1.1.1", poolProps, "subnet-id", 1)

			Expect(err.Error()).To(ContainSubstring("failed to retrieve listener 'the-listener-id'"))
			Expect(poolMember).To(BeNil())
		})

		It("times out while waiting for loadbalancer to become ACTIVE", func() {
			loadbalancerFacade.GetLoadbalancerReturns(&loadbalancers.LoadBalancer{ID: "the-lb-id", ProvisioningStatus: "PENDING_UPDATE"}, nil)

			poolMember, err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				CreatePoolMember(mockPool, "1.1.1.1", poolProps, "subnet-id", 1)

			Expect(err.Error()).To(ContainSubstring("timeout while waiting for loadbalancer 'the-lb-id' to become active"))
			Expect(poolMember).To(BeNil())
		})

		It("returns an error while waiting if getting loadbalancer fails", func() {
			loadbalancerFacade.GetLoadbalancerReturns(nil, errors.New("boom"))

			poolMember, err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				CreatePoolMember(mockPool, "1.1.1.1", poolProps, "subnet-id", 1)

			Expect(err.Error()).To(ContainSubstring("failed to retrieve loadbalancer 'the-lb-id': boom"))
			Expect(poolMember).To(BeNil())
		})

		It("returns an error while waiting if the loadbalancer is in state ERROR", func() {
			loadbalancerFacade.GetLoadbalancerReturns(&loadbalancers.LoadBalancer{ID: "the-lb-id", ProvisioningStatus: "ERROR"}, nil)

			poolMember, err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				CreatePoolMember(mockPool, "1.1.1.1", poolProps, "subnet-id", 1)

			Expect(err.Error()).To(ContainSubstring("loadbalancer status ended up in 'ERROR' state"))
			Expect(poolMember).To(BeNil())
		})

		It("creates a pool member", func() {
			poolMember, err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				CreatePoolMember(mockPool, "1.1.1.1", poolProps, "subnet-id", 1)

			_, poolID, _ := loadbalancerFacade.CreatePoolMemberArgsForCall(0)
			Expect(poolID).To(Equal("pool-id"))

			Expect(err).ToNot(HaveOccurred())
			Expect(poolMember.ID).To(Equal("the-member-id"))
			Expect(poolMember.Address).To(Equal("1.1.1.1"))
			Expect(poolMember.ProtocolPort).To(Equal(1234))
			Expect(poolMember.MonitorPort).To(Equal(5678))
			Expect(poolMember.SubnetID).To(Equal("subnet-id"))
		})

		It("returns an error if creating a pool member fails", func() {
			loadbalancerFacade.CreatePoolMemberReturns(nil, errors.New("boom"))

			_, err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				CreatePoolMember(mockPool, "1.1.1.1", poolProps, "subnet-id", 1)

			Expect(err.Error()).To(Equal("failed to create pool member: boom"))
		})

		It("tries to find the pool member causing the conflict and returns it", func() {
			testError := gophercloud.ErrDefault409{
				ErrUnexpectedResponseCode: gophercloud.ErrUnexpectedResponseCode{Actual: 409},
			}
			loadbalancerFacade.CreatePoolMemberReturns(nil, testError)

			member, err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				CreatePoolMember(mockPool, "1.1.1.1", poolProps, "subnet-id", 1)

			Expect(err).ToNot(HaveOccurred())
			Expect(member).To(Equal(&mockMember))
		})
	})

	Context("DeletePoolMember", func() {
		BeforeEach(func() {
			loadbalancerFacade.GetLoadbalancerReturns(&loadbalancers.LoadBalancer{ID: "the-lb-id", ProvisioningStatus: "ACTIVE"}, nil)
		})

		It("returns an error if getting pool fails", func() {
			loadbalancerFacade.GetPoolReturns(nil, errors.New("boom"))

			err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				DeletePoolMember("pool-id", "member-id", 1)

			Expect(err.Error()).To(ContainSubstring("failed to get pool with ID 'pool-id': boom"))
		})

		It("fails if no loadbalancers nor listeners are associated with pool", func() {
			mockPool.Loadbalancers = []pools.LoadBalancerID{}
			mockPool.Listeners = []pools.ListenerID{}

			err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				DeletePoolMember("pool-id", "member-id", 1)

			Expect(err.Error()).To(ContainSubstring("no load balancers or listeners associated with pool 'pool-id'"))
		})

		It("waits for the loadbalancer to become ACTIVE", func() {
			loadbalancerFacade.GetLoadbalancerReturnsOnCall(0, &loadbalancers.LoadBalancer{ID: "the-lb-id", ProvisioningStatus: "PENDING_UPDATE"}, nil)
			loadbalancerFacade.GetLoadbalancerReturnsOnCall(1, &loadbalancers.LoadBalancer{ID: "the-lb-id", ProvisioningStatus: "ACTIVE"}, nil)

			err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				DeletePoolMember("pool-id", "member-id", 1)

			retryableServiceClient, poolId := loadbalancerFacade.GetPoolArgsForCall(0)
			var utilsRetryableServiceClient utils.RetryableServiceClient
			Expect(retryableServiceClient).To(BeAssignableToTypeOf(utilsRetryableServiceClient))

			Expect(poolId).To(Equal("pool-id"))
			Expect(err).ToNot(HaveOccurred())
			Expect(loadbalancerFacade.DeletePoolMemberCallCount()).To(Equal(1))
		})

		It("times out while waiting for loadbalancer to become ACTIVE", func() {
			loadbalancerFacade.GetLoadbalancerReturns(&loadbalancers.LoadBalancer{ID: "the-lb-id", ProvisioningStatus: "PENDING_UPDATE"}, nil)

			err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				DeletePoolMember("pool-id", "member-id", 1)

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("timeout while waiting for loadbalancer 'the-lb-id' to become active"))
			Expect(loadbalancerFacade.DeletePoolMemberCallCount()).To(Equal(0))
		})

		It("returns an error while waiting if getting loadbalancer fails", func() {
			loadbalancerFacade.GetLoadbalancerReturns(&loadbalancers.LoadBalancer{}, errors.New("boom"))

			err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				DeletePoolMember("pool-id", "member-id", 1)

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("failed to retrieve loadbalancer 'the-lb-id': boom"))
			Expect(loadbalancerFacade.DeletePoolMemberCallCount()).To(Equal(0))
		})

		It("returns an error while waiting if the loadbalancer is in state ERROR", func() {
			loadbalancerFacade.GetLoadbalancerReturns(&loadbalancers.LoadBalancer{ID: "the-lb-id", ProvisioningStatus: "ERROR"}, nil)

			err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				DeletePoolMember("pool-id", "member-id", 1)

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("loadbalancer status ended up in 'ERROR' state"))
			Expect(loadbalancerFacade.DeletePoolMemberCallCount()).To(Equal(0))
		})

		It("deletes pool member", func() {
			err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				DeletePoolMember("pool-id", "member-id", 1)

			retryableServiceClient, _, _ := loadbalancerFacade.DeletePoolMemberArgsForCall(0)
			var utilsRetryableServiceClient utils.RetryableServiceClient
			Expect(retryableServiceClient).To(BeAssignableToTypeOf(utilsRetryableServiceClient))

			Expect(err).ToNot(HaveOccurred())
			Expect(loadbalancerFacade.DeletePoolMemberCallCount()).To(Equal(1))
		})

		It("does not fail if delete pool member returns error-not-found", func() {
			testError := gophercloud.ErrDefault404{
				ErrUnexpectedResponseCode: gophercloud.ErrUnexpectedResponseCode{Actual: 404},
			}
			loadbalancerFacade.DeletePoolMemberReturns(testError)

			err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				DeletePoolMember("pool-name", "member-id", 1)

			Expect(err).ToNot(HaveOccurred())
			Expect(loadbalancerFacade.DeletePoolMemberCallCount()).To(Equal(1))
		})

		It("returns an error if deleting pool member fails", func() {
			loadbalancerFacade.DeletePoolMemberReturns(errors.New("boom"))

			err := loadbalancer.NewLoadbalancerService(serviceClients, &loadbalancerFacade, &logger).
				DeletePoolMember("pool-name", "member-id", 1)

			Expect(err.Error()).To(Equal("failed to delete pool member: boom"))
			Expect(loadbalancerFacade.DeletePoolMemberCallCount()).To(Equal(1))
		})
	})

})
