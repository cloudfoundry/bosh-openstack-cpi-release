package methods_test

import (
	"errors"
	"fmt"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute/computefakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/methods"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/volume/volumefakes"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/extensions/volumeattach"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/servers"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("DetachDiskMethod Unit Tests", func() {

	const (
		volumeId1          = "vol1-id"
		volumeId2          = "vol2-id"
		volumeId3          = "vol3-id"
		deviceA            = "/dev/sda"
		deviceB            = "/dev/sdb"
		serverId           = "VM-id"
		serverStatusActive = "ACTIVE"
	)

	var (
		computeServiceBuilder *computefakes.FakeComputeServiceBuilder
		computeService        *computefakes.FakeComputeService
		volumeServiceBuilder  *volumefakes.FakeVolumeServiceBuilder
		volumeService         *volumefakes.FakeVolumeService
		logger                *utilsfakes.FakeLogger
		cpiConfig             config.CpiConfig
	)

	Context("detaching disk from VM", func() {
		BeforeEach(func() {
			computeServiceBuilder = new(computefakes.FakeComputeServiceBuilder)
			computeService = new(computefakes.FakeComputeService)
			volumeServiceBuilder = new(volumefakes.FakeVolumeServiceBuilder)
			volumeService = new(volumefakes.FakeVolumeService)
			logger = new(utilsfakes.FakeLogger)
			computeServiceBuilder.BuildReturns(computeService, nil)
			cpiConfig = config.CpiConfig{}
		})

		It("fails on compute service builder", func() {
			computeServiceBuilder.BuildReturns(nil, errors.New("boom"))
			detachDiskMethod := methods.NewDetachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			vmCID := apiv1.VMCID{}
			diskCID := apiv1.DiskCID{}
			err := detachDiskMethod.DetachDisk(vmCID, diskCID)
			Expect(err.Error()).To(Equal("detach_disk: Failed to get compute service: boom"))
		})

		It("fails on get VM", func() {
			server := servers.Server{}
			computeService.GetServerReturns(&server, errors.New("boom"))
			detachDiskMethod := methods.NewDetachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			vmCID := apiv1.NewVMCID(serverId)
			diskCID := apiv1.DiskCID{}
			err := detachDiskMethod.DetachDisk(vmCID, diskCID)
			Expect(err.Error()).To(Equal(fmt.Sprintf("detach_disk: Failed to get VM %s: boom", serverId)))
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
			detachDiskMethod := methods.NewDetachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			vmCID := apiv1.NewVMCID(serverId)
			diskCID := apiv1.NewDiskCID(volumeId1)
			err := detachDiskMethod.DetachDisk(vmCID, diskCID)
			Expect(err.Error()).To(Equal(fmt.Sprintf("detach_disk: Failed to get volume attachments for VM ID %s: boom", serverId)))
		})

		It("success: volume is not attached to VM", func() {
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
			detachDiskMethod := methods.NewDetachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			vmCID := apiv1.NewVMCID(serverId)
			diskCID := apiv1.NewDiskCID(volumeId3)
			err := detachDiskMethod.DetachDisk(vmCID, diskCID)
			Expect(err).NotTo(HaveOccurred())
		})

		It("fails on detach volume", func() {
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
			computeService.DetachVolumeReturns(errors.New("boom"))
			detachDiskMethod := methods.NewDetachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			vmCID := apiv1.NewVMCID(serverId)
			diskCID := apiv1.NewDiskCID(volumeId2)
			err := detachDiskMethod.DetachDisk(vmCID, diskCID)
			Expect(err.Error()).To(Equal(fmt.Sprintf("detach_disk: Failed to detach volume %s from VM %s: boom", diskCID.AsString(), vmCID.AsString())))
		})

		It("fails on waiting after detached volume", func() {
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
			computeService.DetachVolumeReturns(nil)
			volumeServiceBuilder.BuildReturns(volumeService, nil)
			cpiConfig.Cloud.Properties.Openstack.StateTimeOut = 10
			volumeService.WaitForVolumeToBecomeStatusReturns(errors.New("boom"))
			detachDiskMethod := methods.NewDetachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			vmCID := apiv1.NewVMCID(serverId)
			diskCID := apiv1.NewDiskCID(volumeId2)
			err := detachDiskMethod.DetachDisk(vmCID, diskCID)
			Expect(err.Error()).To(Equal(fmt.Sprintf("detach_disk: Timeout on waiting for volume ID %s become available (waiting: %d sec): boom", diskCID.AsString(), cpiConfig.Cloud.Properties.Openstack.StateTimeOut)))
		})

		It("success on detach volume", func() {
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
			computeService.DetachVolumeReturns(nil)
			volumeServiceBuilder.BuildReturns(volumeService, nil)
			cpiConfig.Cloud.Properties.Openstack.StateTimeOut = 10
			volumeService.WaitForVolumeToBecomeStatusReturns(nil)
			detachDiskMethod := methods.NewDetachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			vmCID := apiv1.NewVMCID(serverId)
			diskCID := apiv1.NewDiskCID(volumeId2)
			err := detachDiskMethod.DetachDisk(vmCID, diskCID)
			Expect(err).NotTo(HaveOccurred())
		})

	})

})
