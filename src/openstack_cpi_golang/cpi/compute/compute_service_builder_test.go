package compute_test

import (
	"errors"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/openstack/openstackfakes"
	"github.com/gophercloud/gophercloud"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("ComputeServiceBuilder", func() {
	var openstackService openstackfakes.FakeOpenstackService
	var logger utilsfakes.FakeLogger
	var computeServiceBuilder compute.ComputeServiceBuilder

	BeforeEach(func() {
		openstackService = openstackfakes.FakeOpenstackService{}
		logger = utilsfakes.FakeLogger{}
		cpiConfig := config.CpiConfig{}
		cpiConfig.Cloud.Properties.RetryConfig = config.RetryConfigMap{}

		computeServiceBuilder = compute.NewComputeServiceBuilder(
			&openstackService,
			cpiConfig,
			&logger,
		)
	})

	Context("Build", func() {
		It("returns a compute service", func() {
			providerClient := gophercloud.ProviderClient{TokenID: "the_token"}
			serviceClient := gophercloud.ServiceClient{ProviderClient: &providerClient}
			openstackService.ComputeServiceV2Returns(&serviceClient, nil)

			computeService, err := computeServiceBuilder.Build()

			Expect(err).ToNot(HaveOccurred())
			Expect(computeService).To(Not(BeNil()))
		})

		It("returns an error if the compute service client cannot be retrieved", func() {
			openstackService.ComputeServiceV2Returns(nil, errors.New("boom"))

			computeService, err := computeServiceBuilder.Build()

			Expect(err.Error()).To(Equal("failed to retrieve compute service client: boom"))
			Expect(computeService).To(BeNil())
		})
	})
})
