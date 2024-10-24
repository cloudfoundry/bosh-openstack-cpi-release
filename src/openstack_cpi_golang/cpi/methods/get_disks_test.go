package methods_test

import (
	"errors"
	"fmt"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute/computefakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/methods"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/extensions/volumeattach"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/servers"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("GetDisksMethod Unit Tests", func() {

	const (
		volumeId1          = "vol1-id"
		volumeId2          = "vol2-id"
		deviceA            = "/dev/sda"
		deviceB            = "/dev/sdb"
		serverId           = "VM-id"
		serverStatusActive = "ACTIVE"
	)

	var (
		computeServiceBuilder *computefakes.FakeComputeServiceBuilder
		computeService        *computefakes.FakeComputeService
		logger                *utilsfakes.FakeLogger
	)

	Context("get disks attached to a VM", func() {
		BeforeEach(func() {
			computeServiceBuilder = new(computefakes.FakeComputeServiceBuilder)
			computeService = new(computefakes.FakeComputeService)
			logger = new(utilsfakes.FakeLogger)
			computeServiceBuilder.BuildReturns(computeService, nil)
		})

		It("fails on compute service builder", func() {
			computeServiceBuilder.BuildReturns(nil, errors.New("boom"))
			getDisksMethod := methods.NewGetDisksMethod(computeServiceBuilder, logger)
			vmCID := apiv1.VMCID{}
			_, err := getDisksMethod.GetDisks(vmCID)
			Expect(err.Error()).To(Equal("get_disks: Failed to get compute service: boom"))
		})

		It("fails on get VM", func() {
			server := servers.Server{}
			computeService.GetServerReturns(&server, errors.New("boom"))
			getDisksMethod := methods.NewGetDisksMethod(computeServiceBuilder, logger)
			vmCID := apiv1.NewVMCID(serverId)
			_, err := getDisksMethod.GetDisks(vmCID)
			Expect(err.Error()).To(Equal(fmt.Sprintf("get_disks: Failed to get VM %s: boom", serverId)))
		})

		It("fails on list volume attachments", func() {
			computeService = new(computefakes.FakeComputeService)
			computeServiceBuilder.BuildReturns(computeService, nil)
			server := servers.Server{
				ID:     serverId,
				Status: serverStatusActive,
			}
			computeService.GetServerReturns(&server, nil)
			computeService.ListVolumeAttachmentsReturns(nil, errors.New("boom"))
			getDisksMethod := methods.NewGetDisksMethod(computeServiceBuilder, logger)
			vmCID := apiv1.NewVMCID(serverId)
			_, err := getDisksMethod.GetDisks(vmCID)
			Expect(err.Error()).To(Equal(fmt.Sprintf("get_disks: Failed to get volume attachments for VM ID %s: boom", serverId)))
		})

		It("does not fail if volume attachments returns an empty list", func() {
			computeService = new(computefakes.FakeComputeService)
			computeServiceBuilder.BuildReturns(computeService, nil)
			server := servers.Server{
				ID:     serverId,
				Status: serverStatusActive,
			}
			computeService.GetServerReturns(&server, nil)
			var volumeAttachments []volumeattach.VolumeAttachment
			computeService.ListVolumeAttachmentsReturns(volumeAttachments, nil)
			getDisksMethod := methods.NewGetDisksMethod(computeServiceBuilder, logger)
			vmCID := apiv1.NewVMCID(serverId)
			diskCIDs, err := getDisksMethod.GetDisks(vmCID)
			Expect(err).NotTo(HaveOccurred())
			Expect(diskCIDs).To(Equal([]apiv1.DiskCID{}))
		})

		It("successfully gets the disks", func() {
			computeService = new(computefakes.FakeComputeService)
			computeServiceBuilder.BuildReturns(computeService, nil)
			server := servers.Server{
				ID:     serverId,
				Status: serverStatusActive,
			}
			computeService.GetServerReturns(&server, nil)
			volume1 := volumeattach.VolumeAttachment{VolumeID: volumeId1, Device: deviceA}
			volume2 := volumeattach.VolumeAttachment{VolumeID: volumeId2, Device: deviceB}
			var volumeAttachments []volumeattach.VolumeAttachment
			volumeAttachments = append(volumeAttachments, volume1, volume2)
			computeService.ListVolumeAttachmentsReturns(volumeAttachments, nil)
			getDisksMethod := methods.NewGetDisksMethod(computeServiceBuilder, logger)
			vmCID := apiv1.NewVMCID(serverId)
			diskCIDs, err := getDisksMethod.GetDisks(vmCID)
			Expect(err).NotTo(HaveOccurred())
			Expect(diskCIDs).To(Equal([]apiv1.DiskCID{apiv1.NewDiskCID("vol1-id"), apiv1.NewDiskCID("vol2-id")}))
		})

	})

})
