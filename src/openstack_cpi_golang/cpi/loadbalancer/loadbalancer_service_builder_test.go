package loadbalancer_test

import (
	"errors"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/loadbalancer"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/openstack/openstackfakes"
	"github.com/gophercloud/gophercloud"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("LoadbalancerServiceBuilder", func() {
	var openstackService openstackfakes.FakeOpenstackService
	var logger utilsfakes.FakeLogger
	var loadbalancerServiceBuilder loadbalancer.LoadbalancerServiceBuilder

	BeforeEach(func() {
		openstackService = openstackfakes.FakeOpenstackService{}
		logger = utilsfakes.FakeLogger{}
		cpiConfig := config.CpiConfig{}
		cpiConfig.Cloud.Properties.RetryConfig = config.RetryConfigMap{}

		loadbalancerServiceBuilder = loadbalancer.NewLoadbalancerServiceBuilder(
			&openstackService,
			cpiConfig,
			&logger,
		)
	})

	Context("Build", func() {
		It("returns an loadbalancer service", func() {
			providerClient := gophercloud.ProviderClient{TokenID: "the_token"}
			serviceClient := gophercloud.ServiceClient{ProviderClient: &providerClient}
			openstackService.LoadbalancerV2Returns(&serviceClient, nil)

			loadbalancerService, err := loadbalancerServiceBuilder.Build()

			Expect(err).ToNot(HaveOccurred())
			Expect(loadbalancerService).To(Not(BeNil()))
		})

		It("returns an error if the loadbalancer service client cannot be retrieved", func() {
			openstackService.LoadbalancerV2Returns(nil, errors.New("boom"))

			loadbalancerService, err := loadbalancerServiceBuilder.Build()

			Expect(err.Error()).To(Equal("failed to retrieve loadbalancer service client: boom"))
			Expect(loadbalancerService).To(BeNil())
		})
	})
})
