package compute_test

import (
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("AvailabilityZoneProvider", func() {
	Context("GetAvailabilityZones", func() {

		var cloudProps properties.CreateVM

		Context("with cloud property availability_zones", func() {

			BeforeEach(func() {
				cloudProps = properties.CreateVM{}
				cloudProps.AvailabilityZone = ""
			})

			It("returns a single availability zone", func() {
				cloudProps.AvailabilityZones = []string{"z1"}
				zone := compute.NewAvailabilityZoneProvider().
					GetAvailabilityZones(cloudProps)

				Expect(len(zone)).To(Equal(1))
				Expect(zone).To(ContainElement("z1"))
			})

			It("returns a single availability zone", func() {
				cloudProps.AvailabilityZones = []string{"z1", "z2", "z3"}
				zone := compute.NewAvailabilityZoneProvider().
					GetAvailabilityZones(cloudProps)

				Expect(len(zone)).To(Equal(3))
				Expect(zone).To(ContainElements("z1", "z2", "z3"))
			})
		})

		Context("with cloud property availability_zone", func() {

			BeforeEach(func() {
				cloudProps = properties.CreateVM{}
				cloudProps.AvailabilityZones = []string{}
			})

			It("returns a single availability zone", func() {
				cloudProps.AvailabilityZone = "z1"
				zone := compute.NewAvailabilityZoneProvider().
					GetAvailabilityZones(cloudProps)

				Expect(len(zone)).To(Equal(1))
				Expect(zone).To(ContainElement("z1"))
			})
		})
	})
})
