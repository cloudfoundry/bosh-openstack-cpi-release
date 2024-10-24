package volume_test

import (
	"errors"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/openstack/openstackfakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/volume"
	"github.com/gophercloud/gophercloud"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("VolumeServiceBuilder", func() {
	var openstackService openstackfakes.FakeOpenstackService
	var logger utilsfakes.FakeLogger
	var volumeServiceBuilder volume.VolumeServiceBuilder

	BeforeEach(func() {
		openstackService = openstackfakes.FakeOpenstackService{}
		logger = utilsfakes.FakeLogger{}
		cpiConfig := config.CpiConfig{}
		cpiConfig.Cloud.Properties.RetryConfig = config.RetryConfigMap{}

		volumeServiceBuilder = volume.NewVolumeServiceBuilder(
			&openstackService,
			cpiConfig,
			&logger,
		)
	})

	Context("Build", func() {
		It("returns a volume service", func() {
			providerClient := gophercloud.ProviderClient{TokenID: "the_token"}
			serviceClient := gophercloud.ServiceClient{ProviderClient: &providerClient}
			openstackService.BlockStorageV3Returns(&serviceClient, nil)

			volumeService, err := volumeServiceBuilder.Build()

			Expect(err).ToNot(HaveOccurred())
			Expect(volumeService).To(Not(BeNil()))
		})

		It("returns an error if the compute service client cannot be retrieved", func() {
			openstackService.BlockStorageV3Returns(nil, errors.New("boom"))

			volumeService, err := volumeServiceBuilder.Build()

			Expect(err.Error()).To(Equal("failed to retrieve volume service client: boom"))
			Expect(volumeService).To(BeNil())
		})
	})
})
