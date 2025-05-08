package network_test

import (
	"encoding/json"
	"errors"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/mocks"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/network"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/network/networkfakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	"github.com/gophercloud/gophercloud"
	"github.com/gophercloud/gophercloud/openstack/networking/v2/extensions/security/groups"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("NetworkService", func() {
	var serviceClient gophercloud.ServiceClient
	var retryableServiceClient gophercloud.ServiceClient
	var serviceClients utils.ServiceClients
	var networkingFacade networkfakes.FakeNetworkingFacade
	var securityGroupsPage mocks.MockPage
	var logger utilsfakes.FakeLogger

	BeforeEach(func() {
		serviceClient = gophercloud.ServiceClient{}
		retryableServiceClient = gophercloud.ServiceClient{}
		serviceClients = utils.ServiceClients{ServiceClient: &serviceClient, RetryableServiceClient: &retryableServiceClient}
		networkingFacade = networkfakes.FakeNetworkingFacade{}
		securityGroupsPage = mocks.MockPage{}
		logger = utilsfakes.FakeLogger{}

		var networks apiv1.Networks
		err := json.Unmarshal([]byte(`{
				"name1": {
					"type":    "manual",
					"ip":      "1.1.1.1",
					"default": ["gateway"],
					"cloud_properties": {"net_id": "the_net_id_1", "security_groups": ["security_group_1", "security_group_2"]}
				},
				"name3": {
					"type":    "vip",
					"ip":      "3.3.3.3",
					"cloud_properties": {"net_id": "the_net_id_3", "security_groups": ["security_group_3"]}
				}
			}`), &networks)
		Expect(err).ToNot(HaveOccurred())

		//networkConfig, err = network.NewNetworkConfigBuilder(&networkService, networks, config.OpenstackConfig{}, properties.CreateVM{}).Build()
		Expect(err).ToNot(HaveOccurred())
	})

	Context("Resolve", func() {
		It("resolves security groups by id", func() {
			_, _ = network.NewSecurityGroupsResolver(serviceClients, &networkingFacade, &logger).Resolve([]string{"the_group_id"}) //nolint:errcheck

			_, securityGroupID := networkingFacade.GetSecurityGroupsArgsForCall(0)
			Expect(securityGroupID).To(Equal("the_group_id"))
		})

		It("logs a warning if getting security group by id fails", func() {
			networkingFacade.GetSecurityGroupsReturns(nil, errors.New("boom"))

			_, _ = network.NewSecurityGroupsResolver(serviceClients, &networkingFacade, &logger).Resolve([]string{"the_group_id"}) //nolint:errcheck

			_, msg, _ := logger.WarnArgsForCall(0)
			Expect(msg).To(Equal("failed to get security group 'the_group_id' by id: boom. Trying to get security group by name"))
		})

		It("returns an error is resolved security group is nil", func() {
			networkingFacade.GetSecurityGroupsReturns(nil, nil)

			_, err := network.NewSecurityGroupsResolver(serviceClients, &networkingFacade, &logger).Resolve([]string{"the_group_id"})

			Expect(err.Error()).To(Equal("could not resolve security group 'the_group_id'"))
		})

		Context("resolution by ID failed", func() {
			It("list security groups by name", func() {
				networkingFacade.GetSecurityGroupsReturns(nil, nil)
				networkingFacade.ListSecurityGroupsReturns(securityGroupsPage, nil)

				_, _ = network.NewSecurityGroupsResolver(serviceClients, &networkingFacade, &logger).Resolve([]string{"the_group_id"}) //nolint:errcheck

				Expect(networkingFacade.GetSecurityGroupsCallCount()).To(Equal(1))
			})

			It("returns an error if listing security groups fails", func() {
				networkingFacade.GetSecurityGroupsReturns(nil, errors.New("baam"))
				networkingFacade.ListSecurityGroupsReturns(nil, errors.New("boom"))

				_, err := network.NewSecurityGroupsResolver(serviceClients, &networkingFacade, &logger).Resolve([]string{"the_group_name"})

				Expect(err.Error()).To(Equal("failed to get security group 'the_group_name' by name: failed to list security groups: boom"))
			})

			It("extracts security groups", func() {
				networkingFacade.GetSecurityGroupsReturns(nil, errors.New("baam"))
				networkingFacade.ListSecurityGroupsReturns(securityGroupsPage, nil)

				_, _ = network.NewSecurityGroupsResolver(serviceClients, &networkingFacade, &logger).Resolve([]string{"the_group_id"}) //nolint:errcheck

				page := networkingFacade.ExtractSecurityGroupsArgsForCall(0)
				Expect(page).To(Equal(securityGroupsPage))
			})

			It("returns an error if extracts security groups fails", func() {
				networkingFacade.GetSecurityGroupsReturns(nil, errors.New("baam"))
				networkingFacade.ListSecurityGroupsReturns(securityGroupsPage, nil)
				networkingFacade.ExtractSecurityGroupsReturns(nil, errors.New("boom"))

				_, err := network.NewSecurityGroupsResolver(serviceClients, &networkingFacade, &logger).Resolve([]string{"the_group_name"})

				Expect(err.Error()).To(Equal("failed to get security group 'the_group_name' by name: failed to extract security groups: boom"))
			})

			It("returns an error if extracts security groups are empty", func() {
				networkingFacade.GetSecurityGroupsReturns(nil, errors.New("baam"))
				networkingFacade.ListSecurityGroupsReturns(securityGroupsPage, nil)
				networkingFacade.ExtractSecurityGroupsReturns([]groups.SecGroup{}, nil)

				_, err := network.NewSecurityGroupsResolver(serviceClients, &networkingFacade, &logger).Resolve([]string{"the_group_name"})

				Expect(err.Error()).To(Equal("failed to get security group 'the_group_name' by name: security group 'the_group_name' could not be found"))
			})

			It("returns security group ids", func() {
				networkingFacade.GetSecurityGroupsReturnsOnCall(0, &groups.SecGroup{ID: "id1"}, nil)
				networkingFacade.GetSecurityGroupsReturnsOnCall(1, nil, errors.New("baam"))
				networkingFacade.ListSecurityGroupsReturns(securityGroupsPage, nil)
				networkingFacade.ExtractSecurityGroupsReturns([]groups.SecGroup{{ID: "id2"}}, nil)

				securityGroups, err := network.NewSecurityGroupsResolver(serviceClients, &networkingFacade, &logger).Resolve([]string{"id1", "not_id"})
				Expect(err).ToNot(HaveOccurred())
				Expect(securityGroups).To(Equal([]string{"id1", "id2"}))
			})
		})
	})
})
