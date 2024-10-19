package compute_test

import (
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/extensions/bootfromvolume"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/flavors"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("VolumeConfigurator", func() {

	BeforeEach(func() {
	})

	Context("ConfigureVolumes", func() {

		It("uses disk size from cloud properties if defined", func() {
			bootFromVolume := true
			volumes, err := compute.NewVolumeConfigurator().ConfigureVolumes(
				"the_image_id",
				config.OpenstackConfig{},
				properties.CreateVM{
					RootDisk:       properties.Disk{Size: 888},
					BootFromVolume: &bootFromVolume,
				},
				flavors.Flavor{},
			)

			Expect(err).ToNot(HaveOccurred())
			Expect(volumes[0].VolumeSize).To(Equal(888))
		})

		It("uses disk size from the flavor if root disk size is 0 and flavor disk size is > 0", func() {
			bootFromVolume := true
			volumes, err := compute.NewVolumeConfigurator().ConfigureVolumes(
				"the_image_id",
				config.OpenstackConfig{},
				properties.CreateVM{
					RootDisk:       properties.Disk{Size: 0},
					BootFromVolume: &bootFromVolume,
				},
				flavors.Flavor{
					Disk: 999,
				},
			)
			Expect(err).ToNot(HaveOccurred())
			Expect(volumes[0].VolumeSize).To(Equal(999))
		})

		It("returns an error if root disk size is 0 and flavor disk size is 0", func() {
			bootFromVolume := true
			_, err := compute.NewVolumeConfigurator().ConfigureVolumes(
				"the_image_id",
				config.OpenstackConfig{},
				properties.CreateVM{
					RootDisk:       properties.Disk{Size: 0},
					BootFromVolume: &bootFromVolume,
				},
				flavors.Flavor{
					ID:   "the_flavor_id",
					Disk: 0,
				},
			)

			Expect(err.Error()).To(ContainSubstring("failed to get volume size: flavor 'the_flavor_id' has a root disk size of 0."))
		})

		It("returns an empty array of block devices if boot volume is not defined", func() {

			bootFromVolume := true
			volumes, err := compute.NewVolumeConfigurator().ConfigureVolumes(
				"the_image_id",
				config.OpenstackConfig{},
				properties.CreateVM{
					RootDisk:       properties.Disk{Size: 0},
					BootFromVolume: &bootFromVolume,
				},
				flavors.Flavor{
					Disk: 999,
				},
			)

			Expect(err).ToNot(HaveOccurred())
			Expect(volumes[0].UUID).To(Equal("the_image_id"))
			Expect(volumes[0].SourceType).To(Equal(bootfromvolume.SourceImage))
			Expect(volumes[0].DestinationType).To(Equal(bootfromvolume.DestinationVolume))
			Expect(volumes[0].VolumeSize).To(Equal(999))
			Expect(volumes[0].BootIndex).To(Equal(0))
			Expect(volumes[0].DeleteOnTermination).To(BeTrue())
		})

		It("returns a block device", func() {

			volumes, err := compute.NewVolumeConfigurator().ConfigureVolumes(
				"the_image_id",
				config.OpenstackConfig{},
				properties.CreateVM{
					RootDisk: properties.Disk{Size: 0},
				},
				flavors.Flavor{
					Disk: 999,
				},
			)

			Expect(err).ToNot(HaveOccurred())
			Expect(len(volumes)).To(Equal(0))
		})

		//It("return error if list flavors fails", func() {
		//	computeFacade.ListFlavorsReturns(nil, errors.New("boom"))
		//
		//	_, err := NewFlavorResolver(&serviceClient, &computeFacade).ResolveFlavorForInstanceType("the_instance_type")
		//
		//	Expect(err.Error()).To(ContainSubstring("failed to list flavors: boom"))
		//})
		//
		//It("extract flavors", func() {
		//	NewFlavorResolver(&serviceClient, &computeFacade).ResolveFlavorForInstanceType("the_instance_type")
		//
		//	Expect(computeFacade.ExtractFlavorsArgsForCall(0)).To(Equal(flavorsPage))
		//	Expect(computeFacade.ExtractFlavorsCallCount()).To(Equal(1))
		//})
		//
		//It("return error if extract flavors fails", func() {
		//	computeFacade.ExtractFlavorsReturns(nil, errors.New("boom"))
		//
		//	_, err := NewFlavorResolver(&serviceClient, &computeFacade).ResolveFlavorForInstanceType("the_instance_type")
		//
		//	Expect(err.Error()).To(ContainSubstring("failed to extract flavors: boom"))
		//})
		//
		//It("return an error if flavor name is not found", func() {
		//	_, err := NewFlavorResolver(&serviceClient, &computeFacade).ResolveFlavorForInstanceType("not_existing_instance_type")
		//
		//	Expect(err.Error()).To(ContainSubstring("flavor for instance type 'not_existing_instance_type' not found"))
		//})
		//
		//It("return an error if flavor ephemeral disk is to small", func() {
		//	computeFacade.ExtractFlavorsReturns([]flavors.Flavor{{ID: "the_flavor_id", Name: "the_instance_type", RAM: 4096, Ephemeral: 2}}, nil)
		//
		//	_, err := NewFlavorResolver(&serviceClient, &computeFacade).ResolveFlavorForInstanceType("the_instance_type")
		//
		//	Expect(err.Error()).To(ContainSubstring("flavor 'the_instance_type' should have at least 8Gb of ephemeral disk"))
		//})
	})
})
