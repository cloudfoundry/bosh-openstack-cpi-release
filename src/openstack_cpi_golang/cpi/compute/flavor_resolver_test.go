package compute_test

import (
	"errors"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute/computefakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/mocks"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/gophercloud/gophercloud"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/flavors"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("FlavorResolver", func() {

	var serviceClient gophercloud.ServiceClient
	var retryableServiceClient gophercloud.ServiceClient
	var serviceClients utils.ServiceClients
	var computeFacade computefakes.FakeComputeFacade
	var flavorsPage mocks.MockPage

	BeforeEach(func() {
		serviceClient = gophercloud.ServiceClient{}
		retryableServiceClient = gophercloud.ServiceClient{}
		serviceClients = utils.ServiceClients{ServiceClient: &serviceClient, RetryableServiceClient: &retryableServiceClient}
		computeFacade = computefakes.FakeComputeFacade{}

		computeFacade.ListFlavorsReturns(flavorsPage, nil)
		computeFacade.ExtractFlavorsReturns([]flavors.Flavor{{ID: "the_flavor_id", Name: "the_instance_type", VCPUs: 2, RAM: 4096, Ephemeral: 10}}, nil)
	})

	Context("ResolveFlavorForInstanceType", func() {
		It("lists flavors", func() {
			_, _ = compute.NewFlavorResolver(serviceClients, &computeFacade).ResolveFlavorForInstanceType("the_instance_type") //nolint:errcheck

			Expect(computeFacade.ListFlavorsCallCount()).To(Equal(1))
		})

		It("return error if list flavors fails", func() {
			computeFacade.ListFlavorsReturns(nil, errors.New("boom"))

			_, err := compute.NewFlavorResolver(serviceClients, &computeFacade).ResolveFlavorForInstanceType("the_instance_type")

			Expect(err.Error()).To(ContainSubstring("failed to list flavors: boom"))
		})

		It("extract flavors", func() {
			_, _ = compute.NewFlavorResolver(serviceClients, &computeFacade).ResolveFlavorForInstanceType("the_instance_type") //nolint:errcheck

			Expect(computeFacade.ExtractFlavorsArgsForCall(0)).To(Equal(flavorsPage))
			Expect(computeFacade.ExtractFlavorsCallCount()).To(Equal(1))
		})

		It("return error if extract flavors fails", func() {
			computeFacade.ExtractFlavorsReturns(nil, errors.New("boom"))

			_, err := compute.NewFlavorResolver(serviceClients, &computeFacade).ResolveFlavorForInstanceType("the_instance_type")

			Expect(err.Error()).To(ContainSubstring("failed to extract flavors: boom"))
		})

		It("return an error if flavor name is not found", func() {
			_, err := compute.NewFlavorResolver(serviceClients, &computeFacade).ResolveFlavorForInstanceType("not_existing_instance_type")

			Expect(err.Error()).To(ContainSubstring("flavor for instance type 'not_existing_instance_type' not found"))
		})

		It("return an error if flavor ephemeral disk is to small", func() {
			computeFacade.ExtractFlavorsReturns([]flavors.Flavor{{ID: "the_flavor_id", Name: "the_instance_type", RAM: 4096, Ephemeral: 2}}, nil)

			_, err := compute.NewFlavorResolver(serviceClients, &computeFacade).ResolveFlavorForInstanceType("the_instance_type")

			Expect(err.Error()).To(ContainSubstring("flavor 'the_instance_type' should have at least 8Gb of ephemeral disk"))
		})
	})

	Context("ResolveFlavorForRequirements", func() {
		var vmResources apiv1.VMResources
		var bootFromVolume bool

		BeforeEach(func() {
			vmResources = apiv1.VMResources{CPU: 2, RAM: 4096, EphemeralDiskSize: 10}
			bootFromVolume = false
		})

		It("lists flavors", func() {
			_, _ = compute.NewFlavorResolver(serviceClients, &computeFacade).ResolveFlavorForRequirements(vmResources, bootFromVolume) //nolint:errcheck

			Expect(computeFacade.ListFlavorsCallCount()).To(Equal(1))
		})

		It("return error if list flavors fails", func() {
			computeFacade.ListFlavorsReturns(nil, errors.New("boom"))

			_, err := compute.NewFlavorResolver(serviceClients, &computeFacade).ResolveFlavorForRequirements(vmResources, bootFromVolume)

			Expect(err.Error()).To(ContainSubstring("failed to list flavors: boom"))
		})

		It("extract flavors", func() {
			_, _ = compute.NewFlavorResolver(serviceClients, &computeFacade).ResolveFlavorForRequirements(vmResources, bootFromVolume) //nolint:errcheck

			Expect(computeFacade.ExtractFlavorsArgsForCall(0)).To(Equal(flavorsPage))
			Expect(computeFacade.ExtractFlavorsCallCount()).To(Equal(1))
		})

		It("return error if extract flavors fails", func() {
			computeFacade.ExtractFlavorsReturns(nil, errors.New("boom"))

			_, err := compute.NewFlavorResolver(serviceClients, &computeFacade).ResolveFlavorForRequirements(vmResources, bootFromVolume)

			Expect(err.Error()).To(ContainSubstring("failed to extract flavors: boom"))
		})

		It("return an empty slice if no flavor fulfill all requirements regarding VCPUs", func() {
			vmResources.CPU = 4
			possibleFlavors, err := compute.NewFlavorResolver(serviceClients, &computeFacade).ResolveFlavorForRequirements(vmResources, bootFromVolume)

			Expect(err).ToNot(HaveOccurred())
			Expect(possibleFlavors).To(BeEmpty())
		})

		It("return an empty slice if no flavor fulfill all requirements regarding RAM", func() {
			vmResources.RAM = 8192
			possibleFlavors, err := compute.NewFlavorResolver(serviceClients, &computeFacade).ResolveFlavorForRequirements(vmResources, bootFromVolume)

			Expect(err).ToNot(HaveOccurred())
			Expect(possibleFlavors).To(BeEmpty())
		})

		Context("when booting from volume", func() {
			BeforeEach(func() {
				bootFromVolume = true
			})

			It("return an empty slice if all flavors have an ephemeral disk", func() {
				computeFacade.ExtractFlavorsReturns(
					[]flavors.Flavor{
						{ID: "the_flavor_id_1", Name: "the_instance_type_1", VCPUs: 1, RAM: 2048, Ephemeral: 10},
						{ID: "the_flavor_id_2", Name: "the_instance_type_2", VCPUs: 2, RAM: 4096, Ephemeral: 20},
					}, nil)
				possibleFlavors, err := compute.NewFlavorResolver(serviceClients, &computeFacade).ResolveFlavorForRequirements(vmResources, bootFromVolume)

				Expect(err).ToNot(HaveOccurred())
				Expect(possibleFlavors).To(BeEmpty())
			})

			It("return flavor if valid flavor does not have a disk", func() {
				computeFacade.ExtractFlavorsReturns(
					[]flavors.Flavor{
						{ID: "the_flavor_id_1", Name: "the_instance_type_1", VCPUs: 1, RAM: 2048, Ephemeral: 10},
						{ID: "the_flavor_id_2", Name: "the_instance_type_2", VCPUs: 2, RAM: 4096, Ephemeral: 0},
					}, nil)
				possibleFlavors, err := compute.NewFlavorResolver(serviceClients, &computeFacade).ResolveFlavorForRequirements(vmResources, bootFromVolume)

				Expect(err).ToNot(HaveOccurred())
				Expect(possibleFlavors).To(HaveLen(1))
				Expect(possibleFlavors[0].Name).To(Equal("the_instance_type_2"))
			})

		})

		Context("when not booting from volume", func() {
			It("return flavor if valid flavor already fulfill ephemeral and os disk size requirements", func() {
				vmResources.EphemeralDiskSize = 10241
				computeFacade.ExtractFlavorsReturns(
					[]flavors.Flavor{
						{ID: "the_flavor_id_1", Name: "the_instance_type_1", VCPUs: 2, RAM: 4096, Ephemeral: 10, Disk: 3},
						{ID: "the_flavor_id_2", Name: "the_instance_type_2", VCPUs: 2, RAM: 4096, Ephemeral: 20, Disk: 1},
						{ID: "the_flavor_id_3", Name: "the_instance_type_3", VCPUs: 2, RAM: 4096, Ephemeral: 20, Disk: 3},
					}, nil)
				possibleFlavors, err := compute.NewFlavorResolver(serviceClients, &computeFacade).ResolveFlavorForRequirements(vmResources, bootFromVolume)

				Expect(err).ToNot(HaveOccurred())
				Expect(possibleFlavors).To(HaveLen(1))
				Expect(possibleFlavors[0].Name).To(Equal("the_instance_type_3"))
			})

			It("return flavor if valid flavor does not have ephemeral disk but os disk fulfills size requirements", func() {
				vmResources.EphemeralDiskSize = 10241
				computeFacade.ExtractFlavorsReturns(
					[]flavors.Flavor{
						{ID: "the_flavor_id_1", Name: "the_instance_type_1", VCPUs: 2, RAM: 4096, Ephemeral: 10, Disk: 3},
						{ID: "the_flavor_id_2", Name: "the_instance_type_2", VCPUs: 2, RAM: 4096, Ephemeral: 20, Disk: 1},
						{ID: "the_flavor_id_3", Name: "the_instance_type_3", VCPUs: 2, RAM: 4096, Ephemeral: 0, Disk: 10},
						{ID: "the_flavor_id_4", Name: "the_instance_type_4", VCPUs: 2, RAM: 4096, Ephemeral: 0, Disk: 15},
					}, nil)
				possibleFlavors, err := compute.NewFlavorResolver(serviceClients, &computeFacade).ResolveFlavorForRequirements(vmResources, bootFromVolume)

				Expect(err).ToNot(HaveOccurred())
				Expect(possibleFlavors).To(HaveLen(1))
				Expect(possibleFlavors[0].Name).To(Equal("the_instance_type_4"))
			})
		})
	})

	Context("GetClosestMatchedFlavor", func() {
		It("returns the flavor that has the closest match to the requested resources", func() {
			possibleFlavors :=
				[]flavors.Flavor{
					{ID: "the_flavor_id_1", Name: "the_instance_type_1", VCPUs: 1, RAM: 2048, Ephemeral: 10, Disk: 10},
					{ID: "the_flavor_id_2", Name: "the_instance_type_2", VCPUs: 1, RAM: 4096, Ephemeral: 20},
					{ID: "the_flavor_id_3", Name: "the_instance_type_3", VCPUs: 4, RAM: 8192, Ephemeral: 40},
					{ID: "the_flavor_id_4", Name: "the_instance_type_4", VCPUs: 1, RAM: 2048, Ephemeral: 20, Disk: 0},
				}
			possibleFlavor := compute.NewFlavorResolver(serviceClients, &computeFacade).GetClosestMatchedFlavor(possibleFlavors)

			Expect(possibleFlavor.Name).To(Equal("the_instance_type_4"))
		})
	})
})
