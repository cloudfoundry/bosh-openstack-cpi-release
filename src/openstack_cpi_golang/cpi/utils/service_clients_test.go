package utils_test

import (
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	"github.com/gophercloud/gophercloud"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("ServiceClients", func() {
	var utilsRetryableServiceClient utils.RetryableServiceClient
	var utilsServiceClient utils.ServiceClient

	It("returns an error if max retries is reached", func() {
		providerClient := gophercloud.ProviderClient{TokenID: "the_token"}
		serviceClient := gophercloud.ServiceClient{ProviderClient: &providerClient}
		cpiConfig := config.CpiConfig{}
		logger := utilsfakes.FakeLogger{}
		serviceClients := utils.NewServiceClients(&serviceClient, cpiConfig, &logger)

		Expect(serviceClients.ServiceClient).To(BeAssignableToTypeOf(utilsServiceClient))
		Expect(serviceClients.RetryableServiceClient).To(BeAssignableToTypeOf(utilsRetryableServiceClient))
	})
})
