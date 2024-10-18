package methods_test

import (
	"errors"
	"fmt"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute/computefakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/methods"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/flavors"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("HasVMMethod", func() {

	var computeServiceBuilder computefakes.FakeComputeServiceBuilder
	var computeService computefakes.FakeComputeService
	var logger utilsfakes.FakeLogger
	var vmResources apiv1.VMResources
	var cpiConfig config.CpiConfig

	Context("CalculateVMCloudProperties", func() {
		BeforeEach(func() {
			computeServiceBuilder = computefakes.FakeComputeServiceBuilder{}
			logger = utilsfakes.FakeLogger{}
			computeService = computefakes.FakeComputeService{}
			computeServiceBuilder.BuildReturns(&computeService, nil)
			computeService.GetMatchingFlavorReturns(flavors.Flavor{ID: "the_flavor_id", Name: "the_instance_type", VCPUs: 2, RAM: 4096, Ephemeral: 5}, nil)
			vmResources = apiv1.VMResources{CPU: 2, RAM: 4096, EphemeralDiskSize: 10240}
			cpiConfig = config.CpiConfig{
				Cloud: struct {
					Properties config.Properties `json:"properties"`
				}{
					Properties: config.Properties{
						Openstack: config.OpenstackConfig{
							BootFromVolume: false,
						},
					},
				},
			}
		})

		Context("bootFromVolume is false", func() {
			BeforeEach(func() {
				cpiConfig = config.CpiConfig{
					Cloud: struct {
						Properties config.Properties `json:"properties"`
					}{
						Properties: config.Properties{
							Openstack: config.OpenstackConfig{
								BootFromVolume: false,
							},
						},
					},
				}
			})
			It("calculate the vm cloud properties without root disk", func() {
				vmCloudProperties, err := methods.NewCalculateVMCloudPropertiesMethod(
					&computeServiceBuilder,
					cpiConfig,
					&logger,
				).CalculateVMCloudProperties(
					vmResources,
				)

				Expect(computeServiceBuilder.BuildCallCount()).To(Equal(1))
				Expect(computeService.GetMatchingFlavorCallCount()).To(Equal(1))
				flavorArgs, bootFromVolumeArg := computeService.GetMatchingFlavorArgsForCall(0)
				Expect(flavorArgs).To(Equal(vmResources))
				Expect(bootFromVolumeArg).To(Equal(false))
				Expect(vmCloudProperties).To(Equal(apiv1.NewVMCloudPropsFromMap(map[string]interface{}{
					"instance_type": "the_instance_type",
				})))
				Expect(err).ToNot(HaveOccurred())
			})
		})

		Context("bootFromVolume is true", func() {
			BeforeEach(func() {
				cpiConfig = config.CpiConfig{
					Cloud: struct {
						Properties config.Properties `json:"properties"`
					}{
						Properties: config.Properties{
							Openstack: config.OpenstackConfig{
								BootFromVolume: true,
							},
						},
					},
				}
			})

			It("calculate the vm cloud properties with root disk", func() {
				vmCloudProperties, err := methods.NewCalculateVMCloudPropertiesMethod(
					&computeServiceBuilder,
					cpiConfig,
					&logger,
				).CalculateVMCloudProperties(
					vmResources,
				)

				Expect(computeServiceBuilder.BuildCallCount()).To(Equal(1))
				Expect(computeService.GetMatchingFlavorCallCount()).To(Equal(1))
				flavorArgs, bootFromVolumeArg := computeService.GetMatchingFlavorArgsForCall(0)
				Expect(flavorArgs).To(Equal(vmResources))
				Expect(bootFromVolumeArg).To(Equal(true))
				Expect(vmCloudProperties).To(Equal(apiv1.NewVMCloudPropsFromMap(map[string]interface{}{
					"instance_type": "the_instance_type",
					"root_disk": map[string]interface{}{
						"size": fmt.Sprintf("%.1f", float64(10+properties.OsOverheadInGb)),
					},
				})))
				Expect(err).ToNot(HaveOccurred())
			})
		})

		It("returns an error and false if the compute service cannot be retrieved", func() {
			computeServiceBuilder.BuildReturns(nil, errors.New("boom"))

			vmCloudProperties, err := methods.NewCalculateVMCloudPropertiesMethod(
				&computeServiceBuilder,
				cpiConfig,
				&logger,
			).CalculateVMCloudProperties(
				vmResources,
			)

			Expect(vmCloudProperties).To(BeNil())
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("calculate_vm_cloud_properties: boom"))
		})

		It("returns false and error if GetServer fails", func() {
			computeService.GetMatchingFlavorReturns(flavors.Flavor{}, errors.New("boom"))

			vmCloudProperties, err := methods.NewCalculateVMCloudPropertiesMethod(
				&computeServiceBuilder,
				cpiConfig,
				&logger,
			).CalculateVMCloudProperties(
				vmResources,
			)

			Expect(vmCloudProperties).To(BeNil())
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("calculate_vm_cloud_properties: boom"))
		})
	})
})
