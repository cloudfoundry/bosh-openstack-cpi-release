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
	"github.com/gophercloud/gophercloud/openstack/blockstorage/v3/volumes"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/extensions/volumeattach"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/flavors"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/servers"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("AttachDiskMethod Unit Tests", func() {

	const (
		volumeId1              = "vol1-id"
		deviceA                = "/dev/sda"
		deviceB                = "/dev/sdb"
		deviceC                = "/dev/sdc"
		serverId               = "VM-id"
		anotherServerId        = "anotherVM-id"
		diskStatusAvailable    = "available"
		diskStatusNotAvailable = "creating"
		diskStatusInUse        = "in-use"
		serverStatusActive     = "ACTIVE"
		serverStatusDeleted    = "DELETED"
	)

	var (
		computeServiceBuilder *computefakes.FakeComputeServiceBuilder
		computeService        *computefakes.FakeComputeService
		volumeServiceBuilder  *volumefakes.FakeVolumeServiceBuilder
		volumeService         *volumefakes.FakeVolumeService
		logger                *utilsfakes.FakeLogger
		cpiConfig             config.CpiConfig
		server                servers.Server
	)

	Context("attaching disk to VM", func() {
		BeforeEach(func() {
			computeServiceBuilder = new(computefakes.FakeComputeServiceBuilder)
			computeService = new(computefakes.FakeComputeService)
			volumeServiceBuilder = new(volumefakes.FakeVolumeServiceBuilder)
			volumeService = new(volumefakes.FakeVolumeService)
			logger = new(utilsfakes.FakeLogger)
			computeServiceBuilder.BuildReturns(computeService, nil)
			cpiConfig = config.CpiConfig{}
		})

		It("fails on volume service builder (V1)", func() {
			volumeServiceBuilder.BuildReturns(nil, errors.New("boom"))
			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			vmCID := apiv1.VMCID{}
			diskId := apiv1.DiskCID{}
			err := attachDiskMethod.AttachDisk(vmCID, diskId)
			Expect(err.Error()).To(Equal("attach_disk: Failed to get volume service: boom"))
		})

		It("fails on get server", func() {
			volumeService.GetVolumeReturns(nil, errors.New("boom"))
			volumeServiceBuilder.BuildReturns(volumeService, nil)
			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			vmCID := apiv1.VMCID{}
			diskId := apiv1.NewDiskCID(volumeId1)
			err := attachDiskMethod.AttachDisk(vmCID, diskId)
			Expect(err.Error()).To(Equal("attach_disk: Failed to get volume with ID vol1-id: boom"))
		})

		It("fails due to disk attach checks (V1): volume is attached to another VM", func() {
			volume := volumes.Volume{
				ID: volumeId1,
				Attachments: []volumes.Attachment{
					{
						Device:   deviceA,
						ServerID: anotherServerId,
					},
				},
			}
			volumeService.GetVolumeReturns(&volume, nil)
			volumeServiceBuilder.BuildReturns(volumeService, nil)
			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			vmCID := apiv1.NewVMCID(serverId)
			diskCID := apiv1.NewDiskCID(volumeId1)
			err := attachDiskMethod.AttachDisk(vmCID, diskCID)
			Expect(err.Error()).To(Equal(fmt.Sprintf("attach_disk: Disk with ID vol1-id cannot be attached: volume %s is attached to another VM", volumeId1)))
		})

		It("success attach (V1): volume is already attached to same VM", func() {
			volume := volumes.Volume{
				ID: volumeId1,
				Attachments: []volumes.Attachment{
					{
						Device:   deviceA,
						ServerID: serverId,
					},
				},
			}
			volumeService.GetVolumeReturns(&volume, nil)
			volumeServiceBuilder.BuildReturns(volumeService, nil)
			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			vmCID := apiv1.NewVMCID(serverId)
			diskCID := apiv1.NewDiskCID(volumeId1)
			err := attachDiskMethod.AttachDisk(vmCID, diskCID)
			Expect(err).NotTo(HaveOccurred())
		})

		It("success attach (V2): volume is already attached to same VM", func() {
			volume := volumes.Volume{
				ID: volumeId1,
				Attachments: []volumes.Attachment{
					{
						Device:   deviceA,
						ServerID: serverId,
					},
				},
			}
			volumeService.GetVolumeReturns(&volume, nil)
			volumeServiceBuilder.BuildReturns(volumeService, nil)
			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			vmCID := apiv1.NewVMCID(serverId)
			diskCID := apiv1.NewDiskCID(volumeId1)
			diskHint, err := attachDiskMethod.AttachDiskV2(vmCID, diskCID)
			Expect(err).NotTo(HaveOccurred())
			diskHintExpected := apiv1.NewDiskHintFromString(deviceA)
			Expect(diskHint).To(Equal(diskHintExpected))
		})

		It("fails due to disk attach checks (V1): volume is not available", func() {
			// volume statuses: https://docs.openstack.org/api-ref/block-storage/v3/index.html#volumes-volumes
			volume := volumes.Volume{
				ID:     volumeId1,
				Status: diskStatusNotAvailable,
			}
			volumeService.GetVolumeReturns(&volume, nil)
			volumeServiceBuilder.BuildReturns(volumeService, nil)
			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			vmCID := apiv1.NewVMCID(serverId)
			diskCID := apiv1.NewDiskCID(volumeId1)
			err := attachDiskMethod.AttachDisk(vmCID, diskCID)
			Expect(err.Error()).To(Equal(fmt.Sprintf("attach_disk: Disk with ID vol1-id cannot be attached: volume %s has not status 'available', current status is '%s'", volumeId1, diskStatusNotAvailable)))
		})

		It("fails due to compute service build (V1)", func() {
			computeServiceBuilder.BuildReturns(nil, errors.New("boom"))
			volume := volumes.Volume{
				ID:     volumeId1,
				Status: diskStatusAvailable,
			}
			volumeService.GetVolumeReturns(&volume, nil)
			volumeServiceBuilder.BuildReturns(volumeService, nil)
			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			vmCID := apiv1.NewVMCID(serverId)
			diskCID := apiv1.NewDiskCID(volumeId1)
			err := attachDiskMethod.AttachDisk(vmCID, diskCID)
			Expect(err.Error()).To(Equal("attach_disk: Failed to get compute service for disk ID vol1-id: boom"))
		})

		It("fails due to get VM (V1)", func() {
			server := servers.Server{}
			computeService.GetServerReturns(&server, errors.New("boom"))
			volume := volumes.Volume{
				ID:     volumeId1,
				Status: diskStatusAvailable,
			}
			volumeService.GetVolumeReturns(&volume, nil)
			volumeServiceBuilder.BuildReturns(volumeService, nil)
			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			vmCID := apiv1.NewVMCID(serverId)
			diskCID := apiv1.NewDiskCID(volumeId1)
			err := attachDiskMethod.AttachDisk(vmCID, diskCID)
			Expect(err.Error()).To(Equal(fmt.Sprintf("attach_disk: Failed to get VM %s for disk ID %s: boom", serverId, volumeId1)))
		})

		It("fails due to VM status is DELETED or TERMINATED (V1)", func() {
			server := servers.Server{
				ID:     serverId,
				Status: serverStatusDeleted,
			}
			computeService.GetServerReturns(&server, nil)
			volume := volumes.Volume{
				ID:     volumeId1,
				Status: diskStatusAvailable,
			}
			volumeService.GetVolumeReturns(&volume, nil)
			volumeServiceBuilder.BuildReturns(volumeService, nil)
			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			vmCID := apiv1.NewVMCID(serverId)
			diskCID := apiv1.NewDiskCID(volumeId1)
			// since we do not explicitly check any more for VM status (DELETED, TERMINATED), we expect an error from attachDisk itself
			// this is just a simulation of the previous behavior with explicit check
			computeService.AttachVolumeReturns(nil, errors.New("VM is in invalid state"))

			err := attachDiskMethod.AttachDisk(vmCID, diskCID)
			Expect(err.Error()).To(Equal(fmt.Sprintf("attach_disk: Failed to attach volume ID %s to VM ID %s: VM is in invalid state", volumeId1, serverId)))
		})

		It("fails due to attach disk failure (V1)", func() {
			server := servers.Server{
				ID:     serverId,
				Status: serverStatusActive,
			}
			computeService.GetServerReturns(&server, nil)
			volume := volumes.Volume{
				ID:     volumeId1,
				Status: diskStatusAvailable,
			}
			volumeService.GetVolumeReturns(&volume, nil)
			volumeServiceBuilder.BuildReturns(volumeService, nil)
			computeService.AttachVolumeReturns(nil, errors.New("boom"))
			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			vmCID := apiv1.NewVMCID(serverId)
			diskCID := apiv1.NewDiskCID(volumeId1)
			err := attachDiskMethod.AttachDisk(vmCID, diskCID)
			Expect(err.Error()).To(Equal(fmt.Sprintf("attach_disk: Failed to attach volume ID %s to VM ID %s: boom", volumeId1, serverId)))
		})

		It("fails on attach disk becoming available within timeout period (V1)", func() {
			server := servers.Server{
				ID:     serverId,
				Status: serverStatusActive,
			}
			computeService.GetServerReturns(&server, nil)
			volume := volumes.Volume{
				ID:     volumeId1,
				Status: diskStatusAvailable,
			}
			volumeService.GetVolumeReturns(&volume, nil)
			volumeServiceBuilder.BuildReturns(volumeService, nil)
			volumeAttach := volumeattach.VolumeAttachment{}
			computeService.AttachVolumeReturns(&volumeAttach, nil)
			volumeService.WaitForVolumeToBecomeStatusReturns(errors.New("boom"))
			cpiConfig.Cloud.Properties.Openstack.StateTimeOut = 60
			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			vmCID := apiv1.NewVMCID(serverId)
			diskCID := apiv1.NewDiskCID(volumeId1)
			err := attachDiskMethod.AttachDisk(vmCID, diskCID)
			Expect(err.Error()).To(Equal(fmt.Sprintf("attach_disk: Timeout on waiting to attach volume ID %s to VM %s (waiting: 60 sec): boom", volumeId1, serverId)))
		})

		It("success on attach disk (V1)", func() {
			server := servers.Server{
				ID:     serverId,
				Status: serverStatusActive,
			}
			computeService.GetServerReturns(&server, nil)
			volume := volumes.Volume{
				ID:     volumeId1,
				Status: diskStatusAvailable,
			}
			volumeService.GetVolumeReturns(&volume, nil)
			volumeServiceBuilder.BuildReturns(volumeService, nil)
			volumeAttach := volumeattach.VolumeAttachment{}
			computeService.AttachVolumeReturns(&volumeAttach, nil)
			volumeService.WaitForVolumeToBecomeStatusReturns(nil)
			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			vmCID := apiv1.NewVMCID(serverId)
			diskCID := apiv1.NewDiskCID(volumeId1)
			err := attachDiskMethod.AttachDisk(vmCID, diskCID)
			Expect(err).NotTo(HaveOccurred())
		})

		It("success on attach disk - includes disk hint (V2)", func() {
			server := servers.Server{
				ID:     serverId,
				Status: serverStatusActive,
			}
			computeService.GetServerReturns(&server, nil)
			volumeNoAttachment := volumes.Volume{
				ID:     volumeId1,
				Status: diskStatusAvailable,
			}
			volume := volumes.Volume{
				ID:     volumeId1,
				Status: diskStatusInUse,
				Attachments: []volumes.Attachment{
					{
						Device:   deviceB,
						ServerID: serverId,
					},
				},
			}
			// given disk/volume is changing its status, reflecting its status before + after attaching
			volumeService.GetVolumeReturnsOnCall(0, &volumeNoAttachment, nil)
			volumeService.GetVolumeReturnsOnCall(1, &volume, nil)
			volumeServiceBuilder.BuildReturns(volumeService, nil)
			volumeAttach := volumeattach.VolumeAttachment{}
			computeService.AttachVolumeReturns(&volumeAttach, nil)
			volumeService.WaitForVolumeToBecomeStatusReturns(nil)
			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			vmCID := apiv1.NewVMCID(serverId)
			diskCID := apiv1.NewDiskCID(volumeId1)
			diskHint, err := attachDiskMethod.AttachDiskV2(vmCID, diskCID)
			Expect(err).NotTo(HaveOccurred())
			diskHintExpected := apiv1.NewDiskHintFromString(deviceB)
			Expect(diskHint).To(Equal(diskHintExpected))
		})

		It("success on attach disk - failure on hint build - failure on getting volume (V2)", func() {
			server := servers.Server{
				ID:     serverId,
				Status: serverStatusActive,
			}
			computeService.GetServerReturns(&server, nil)
			volumeNoAttachment := volumes.Volume{
				ID:     volumeId1,
				Status: diskStatusAvailable,
			}
			// second get volume call fails on disk hint creation
			volumeService.GetVolumeReturnsOnCall(0, &volumeNoAttachment, nil)
			volumeService.GetVolumeReturnsOnCall(1, nil, errors.New("boom"))

			volumeServiceBuilder.BuildReturns(volumeService, nil)
			volumeAttach := volumeattach.VolumeAttachment{}
			computeService.AttachVolumeReturns(&volumeAttach, nil)
			volumeService.WaitForVolumeToBecomeStatusReturns(nil)
			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			vmCID := apiv1.NewVMCID(serverId)
			diskCID := apiv1.NewDiskCID(volumeId1)
			diskHint, err := attachDiskMethod.AttachDiskV2(vmCID, diskCID)
			Expect(err).NotTo(HaveOccurred())
			diskHintExpected := apiv1.DiskHint{}
			Expect(diskHint).To(Equal(diskHintExpected))
		})

	})

	Context("getting mount point", func() {

		BeforeEach(func() {
			computeServiceBuilder = new(computefakes.FakeComputeServiceBuilder)
			computeService = new(computefakes.FakeComputeService)
			volumeServiceBuilder = new(volumefakes.FakeVolumeServiceBuilder)
			volumeService = new(volumefakes.FakeVolumeService)
			logger = new(utilsfakes.FakeLogger)
			computeServiceBuilder.BuildReturns(computeService, nil)
			cpiConfig = config.CpiConfig{}
		})

		It("fails on get for first device letter on flavor ID read", func() {
			flavorMap := map[string]interface{}{
				"id": "1",
			}
			server = servers.Server{Flavor: flavorMap}
			computeService.GetFlavorByIdReturns(flavors.Flavor{}, errors.New("boom"))
			volume := volumes.Volume{}
			volumeService.GetVolumeReturns(&volume, nil)
			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			result, err := attachDiskMethod.GetMountPoint(computeService, server)
			Expect(err).NotTo(HaveOccurred())
			Expect(result).To(Equal(deviceB))
		})

		It("server w/o attached volumes", func() {
			volumeService.GetVolumeReturns(nil, errors.New("boom"))
			volumeServiceBuilder.BuildReturns(volumeService, nil)
			server = servers.Server{}
			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			result, err := attachDiskMethod.GetMountPoint(computeService, server)
			Expect(err).NotTo(HaveOccurred())
			Expect(result).To(Equal(deviceB))
		})

		It("server w/ attached volumes: checking disk attachments", func() {
			var volumeAttachments []volumeattach.VolumeAttachment
			volume1 := volumeattach.VolumeAttachment{VolumeID: volumeId1, Device: deviceA}
			volume2 := volumeattach.VolumeAttachment{VolumeID: volumeId1, Device: deviceB}
			volumeAttachments = append(volumeAttachments, volume1, volume2)
			computeService.ListVolumeAttachmentsReturns(volumeAttachments, nil)
			server = servers.Server{ID: serverId}
			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			result, err := attachDiskMethod.GetMountPoint(computeService, server)
			Expect(err).NotTo(HaveOccurred())
			Expect(result).To(Equal(deviceC))
		})

		It("check overflow of device character search", func() {
			var attachedVolumes []volumeattach.VolumeAttachment
			for i := 1; i < 26; i++ { // omit "a"; search start with "b"
				id := fmt.Sprintf("vol%d-id", i+1)
				device := fmt.Sprintf("/dev/sd%c", 'a'+i)
				attachedVolumes = append(attachedVolumes, volumeattach.VolumeAttachment{VolumeID: id, Device: device})
			}
			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			_, err := attachDiskMethod.GetDeviceChar('b', attachedVolumes)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("failed to get device letter"))
		})

		It("check for the lowest device char", func() {
			var attachedVolumes []volumeattach.VolumeAttachment
			for i := 1; i < 26; i++ { // omit "a"; search start with "b"
				// omit additional drive letter, e.g. 'e' (i == 4), i.e. /dev/...e not in list
				if i == 4 {
					continue
				}
				var device string
				id := fmt.Sprintf("vol%d-id", i+1)
				if i%2 == 0 {
					device = fmt.Sprintf("/dev/sd%c", 'a'+i)
				} else if i%3 == 0 {
					device = fmt.Sprintf("/dev/vd%c", 'a'+i)
				} else {
					device = fmt.Sprintf("/dev/xvd%c", 'a'+i)
				}
				attachedVolumes = append(attachedVolumes, volumeattach.VolumeAttachment{VolumeID: id, Device: device})
			}
			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			driveLetter, err := attachDiskMethod.GetDeviceChar('b', attachedVolumes)
			Expect(err).NotTo(HaveOccurred())
			Expect(driveLetter).To(Equal('e'))
		})

	})

	Context("determine device name letter", func() {

		BeforeEach(func() {
			computeServiceBuilder = new(computefakes.FakeComputeServiceBuilder)
			volumeServiceBuilder = new(volumefakes.FakeVolumeServiceBuilder)
			computeService = new(computefakes.FakeComputeService)
			logger = new(utilsfakes.FakeLogger)
			computeServiceBuilder.BuildReturns(computeService, nil)
			cpiConfig = config.CpiConfig{}
		})

		It("returns default first device name letter on no flavor + no config", func() {
			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			result, err := attachDiskMethod.GetFirstDeviceNameLetterWrapper(computeService, server)
			Expect(err).NotTo(HaveOccurred())
			Expect(result).To(Equal('b'))
		})

		It("on first device name letter: fails to get flavor by ID", func() {
			flavorMap := map[string]interface{}{
				"id": "1",
			}
			server = servers.Server{Flavor: flavorMap}
			computeService.GetFlavorByIdReturns(flavors.Flavor{}, errors.New("boom"))

			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			result, err := attachDiskMethod.GetFirstDeviceNameLetterWrapper(computeService, server)
			Expect(err).NotTo(HaveOccurred())
			Expect(result).To(Equal('b'))
		})

		It("returns specific first device name letter when using flavor: using Ephemeral ", func() {
			flavorMap := map[string]interface{}{
				"id": "1",
			}
			flavor := flavors.Flavor{
				ID:        "1",
				Ephemeral: 1,
			}
			server = servers.Server{Flavor: flavorMap}
			computeService.GetFlavorByIdReturns(flavor, nil)

			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			result, err := attachDiskMethod.GetFirstDeviceNameLetterWrapper(computeService, server)
			Expect(err).NotTo(HaveOccurred())
			Expect(result).To(Equal('c'))
		})

		It("returns specific first device name letter when using flavor: using Swap ", func() {
			flavorMap := map[string]interface{}{
				"id": "1",
			}
			flavor := flavors.Flavor{
				ID:   "1",
				Swap: 1,
			}
			server = servers.Server{Flavor: flavorMap}
			computeService.GetFlavorByIdReturns(flavor, nil)

			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			result, err := attachDiskMethod.GetFirstDeviceNameLetterWrapper(computeService, server)
			Expect(err).NotTo(HaveOccurred())
			Expect(result).To(Equal('c'))
		})

		It("returns specific first device name letter when using flavor: using Ephemeral + Swap ", func() {
			flavorMap := map[string]interface{}{
				"id": "1",
			}
			flavor := flavors.Flavor{
				ID:        "1",
				Swap:      1,
				Ephemeral: 1,
			}
			server = servers.Server{Flavor: flavorMap}
			computeService.GetFlavorByIdReturns(flavor, nil)

			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			result, err := attachDiskMethod.GetFirstDeviceNameLetterWrapper(computeService, server)
			Expect(err).NotTo(HaveOccurred())
			Expect(result).To(Equal('d'))
		})

		It("returns specific first device name letter when using config: setting 'disk'", func() {
			flavorMap := map[string]interface{}{
				"id": "1",
			}
			flavor := flavors.Flavor{
				ID: "1",
			}
			cpiConfig.Cloud.Properties.Openstack.ConfigDrive = "disk"
			server = servers.Server{Flavor: flavorMap}
			computeService.GetFlavorByIdReturns(flavor, nil)

			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			result, err := attachDiskMethod.GetFirstDeviceNameLetterWrapper(computeService, server)
			Expect(err).NotTo(HaveOccurred())
			Expect(result).To(Equal('c'))
		})

		It("returns specific first device name letter when using flavor + config: Ephemeral + Swap, setting 'disk'", func() {
			flavorMap := map[string]interface{}{
				"id": "1",
			}
			flavor := flavors.Flavor{
				ID:        "1",
				Swap:      1,
				Ephemeral: 1,
			}
			cpiConfig.Cloud.Properties.Openstack.ConfigDrive = "disk"
			server = servers.Server{Flavor: flavorMap}
			computeService.GetFlavorByIdReturns(flavor, nil)

			attachDiskMethod := methods.NewAttachDiskMethod(computeServiceBuilder, volumeServiceBuilder, cpiConfig, logger)
			result, err := attachDiskMethod.GetFirstDeviceNameLetterWrapper(computeService, server)
			Expect(err).NotTo(HaveOccurred())
			Expect(result).To(Equal('e'))
		})

	})

})
