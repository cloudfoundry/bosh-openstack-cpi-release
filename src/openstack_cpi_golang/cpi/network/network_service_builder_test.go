package network_test

import (
	"errors"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/network"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/openstack/openstackfakes"
	"github.com/gophercloud/gophercloud"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("NetworkServiceBuilder", func() {
	var openstackService openstackfakes.FakeOpenstackService
	var logger utilsfakes.FakeLogger
	var networkServiceBuilder network.NetworkServiceBuilder

	BeforeEach(func() {
		openstackService = openstackfakes.FakeOpenstackService{}
		logger = utilsfakes.FakeLogger{}
		cpiConfig := config.CpiConfig{}
		cpiConfig.Cloud.Properties.RetryConfig = config.RetryConfigMap{}

		networkServiceBuilder = network.NewNetworkServiceBuilder(
			&openstackService,
			cpiConfig,
			&logger,
		)
	})

	Context("CreateNetworkService", func() {
		It("returns a network service", func() {
			providerClient := gophercloud.ProviderClient{TokenID: "the_token"}
			serviceClient := gophercloud.ServiceClient{ProviderClient: &providerClient}
			openstackService.NetworkServiceV2Returns(&serviceClient, nil)

			computeService, err := networkServiceBuilder.Build()

			Expect(err).ToNot(HaveOccurred())
			Expect(computeService).To(Not(BeNil()))
		})

		It("returns an error if the compute service client cannot be retrieved", func() {
			openstackService.NetworkServiceV2Returns(nil, errors.New("boom"))

			computeService, err := networkServiceBuilder.Build()

			Expect(err.Error()).To(Equal("failed to retrieve network service client: boom"))
			Expect(computeService).To(BeNil())
		})
	})
})
