package cpi_test

import (
	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Factory", func() {
	var (
		cpiConfig config.CpiConfig
		logger    utilsfakes.FakeLogger
		factory   cpi.Factory
	)

	BeforeEach(func() {
		cpiConfig = config.CpiConfig{}
		cpiConfig.Cloud.Properties.Openstack = config.OpenstackConfig{
			AuthURL:  "https://osdash-po-b01.example.com:5000/v3/auth",
			Username: "the_username",
			APIKey:   "the_api_key",
			Region:   "PO-B",
		}
		logger = utilsfakes.FakeLogger{}
		factory = cpi.NewFactory(cpiConfig, &logger)
	})

	Describe("New", func() {
		It("builds a CPI even when the call context overrides the OpenStack endpoint, as a multi-CPI director would", func() {
			ctx := apiv1.CloudPropsImpl{RawMessage: []byte(`{
				"auth_url": "https://osvip-po-c01.example.com:5000/v3/auth",
				"region": "PO-C"
			}`)}

			_, err := factory.New(ctx)

			Expect(err).ToNot(HaveOccurred())
		})

		It("builds a CPI when no OpenStack overrides are present in the context", func() {
			ctx := apiv1.CloudPropsImpl{RawMessage: []byte(`{"director_uuid": "some-director-uuid"}`)}

			_, err := factory.New(ctx)

			Expect(err).ToNot(HaveOccurred())
		})

		It("returns an error when the call context cannot be parsed", func() {
			ctx := apiv1.CloudPropsImpl{RawMessage: []byte(`not-json`)}

			_, err := factory.New(ctx)

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("failed to resolve openstack configuration from CPI call context"))
		})
	})
})
