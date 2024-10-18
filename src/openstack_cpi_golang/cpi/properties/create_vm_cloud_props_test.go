package properties_test

import (
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("CreateVM", func() {

	Context("Validate", func() {

		var openstackConfig config.OpenstackConfig

		BeforeEach(func() {
			openstackConfig = config.OpenstackConfig{}
		})

		It("returns an error if a loadbalancer has no name", func() {
			cloudProps := properties.CreateVM{
				LoadbalancerPools: []properties.LoadbalancerPool{{ProtocolPort: 1234}},
			}

			err := cloudProps.Validate(openstackConfig)

			Expect(err.Error()).To(Equal("load balancer pool defined without name"))
		})

		It("returns an error if a loadbalancer has no port", func() {
			cloudProps := properties.CreateVM{
				LoadbalancerPools: []properties.LoadbalancerPool{{Name: "name"}},
			}

			err := cloudProps.Validate(openstackConfig)

			Expect(err.Error()).To(Equal("load balancer pool 'name' has no port definition"))
		})

		It("returns an error if 'availability_zone' and 'availability_zones' is configured", func() {
			cloudProps := properties.CreateVM{
				AvailabilityZone:  "az1",
				AvailabilityZones: []string{"az1", "az2"},
			}

			err := cloudProps.Validate(openstackConfig)

			Expect(err.Error()).To(Equal("only one property of 'availability_zone' and 'availability_zones' can be configured"))
		})

		It("returns an error if 'availability_zones' are configured without ignore_server_availability_zone", func() {
			cloudProps := properties.CreateVM{
				AvailabilityZones: []string{"az1", "az2"},
			}

			err := cloudProps.Validate(openstackConfig)

			Expect(err.Error()).To(Equal("cannot use multiple azs without 'openstack.ignore_server_availability_zone' set to true"))
		})

	})
})
