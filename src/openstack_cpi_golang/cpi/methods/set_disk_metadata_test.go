package methods_test

import (
	"errors"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute/computefakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/methods"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/volume/volumefakes"
	"github.com/gophercloud/gophercloud/openstack/blockstorage/v3/volumes"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("SetDiskMetadataMethod Unit Tests", func() {

	const (
		volumeId1 = "vol1-id"
		key1      = "key1"
		key2      = "key2"
		value1    = "value1"
		value2    = "value2"
	)

	var (
		computeServiceBuilder *computefakes.FakeComputeServiceBuilder
		volumeServiceBuilder  *volumefakes.FakeVolumeServiceBuilder
		volumeService         *volumefakes.FakeVolumeService
		logger                *utilsfakes.FakeLogger
	)

	Context("setting disk metadata", func() {
		BeforeEach(func() {
			volumeServiceBuilder = new(volumefakes.FakeVolumeServiceBuilder)
			logger = new(utilsfakes.FakeLogger)
		})

		It("fails on volume service builder", func() {
			volumeServiceBuilder.BuildReturns(nil, errors.New("boom"))
			setDiskMetadata := methods.NewSetDiskMetadataMethod(computeServiceBuilder, volumeServiceBuilder, logger)
			diskCID := apiv1.NewDiskCID(volumeId1)
			diskMeta := apiv1.DiskMeta{}
			err := setDiskMetadata.SetDiskMetadata(diskCID, diskMeta)
			Expect(err.Error()).To(Equal("set_disk_metadata: Failed to get volume service: boom"))
		})

		It("fails on get volume", func() {
			volumeService = new(volumefakes.FakeVolumeService)
			volumeServiceBuilder.BuildReturns(volumeService, nil)
			volumeService.GetVolumeReturns(nil, errors.New("boom"))
			setDiskMetadata := methods.NewSetDiskMetadataMethod(computeServiceBuilder, volumeServiceBuilder, logger)
			diskCID := apiv1.NewDiskCID(volumeId1)
			diskMeta := apiv1.DiskMeta{}
			err := setDiskMetadata.SetDiskMetadata(diskCID, diskMeta)
			Expect(err.Error()).To(Equal("set_disk_metadata: Failed to get volume ID vol1-id: boom"))
		})

		It("fails to marshal metadata", func() {
			volumeService = new(volumefakes.FakeVolumeService)
			volumeServiceBuilder.BuildReturns(volumeService, nil)
			volume := volumes.Volume{
				ID: volumeId1,
			}
			volumeService.GetVolumeReturns(&volume, nil)
			diskCID := apiv1.NewDiskCID(volumeId1)
			invalid := map[string]interface{}{
				key1: func() {}, // cannot be marshaled
			}
			diskMeta := apiv1.NewDiskMeta(invalid)
			setDiskMetadata := methods.NewSetDiskMetadataMethod(computeServiceBuilder, volumeServiceBuilder, logger)
			err := setDiskMetadata.SetDiskMetadata(diskCID, diskMeta)
			Expect(err).To(MatchError(ContainSubstring("set_disk_metadata: Failed to marshal metadata for volume ID vol1-id")))
		})

		It("fails to unmarshal metadata", func() {
			volumeService = new(volumefakes.FakeVolumeService)
			volumeServiceBuilder.BuildReturns(volumeService, nil)
			volume := volumes.Volume{
				ID: volumeId1,
			}
			volumeService.GetVolumeReturns(&volume, nil)
			diskCID := apiv1.NewDiskCID(volumeId1)
			invalid := map[string]interface{}{
				key1: value1,
				key2: map[string]interface{}{
					"key": "value",
				},
			}
			diskMeta := apiv1.NewDiskMeta(invalid)
			setDiskMetadata := methods.NewSetDiskMetadataMethod(computeServiceBuilder, volumeServiceBuilder, logger)
			err := setDiskMetadata.SetDiskMetadata(diskCID, diskMeta)
			Expect(err).To(MatchError(ContainSubstring("set_disk_metadata: Failed to unmarshal metadata for volume ID vol1-id")))
		})

		It("success on metadata set", func() {
			volumeService = new(volumefakes.FakeVolumeService)
			volumeServiceBuilder.BuildReturns(volumeService, nil)
			volume := volumes.Volume{
				ID: volumeId1,
				Metadata: map[string]string{
					key1: value1,
					key2: value2,
				},
			}
			volumeService.GetVolumeReturns(&volume, nil)
			diskCID := apiv1.NewDiskCID(volumeId1)
			valid := map[string]interface{}{
				key1: value1,
				key2: value2,
			}
			diskMeta := apiv1.NewDiskMeta(valid)
			setDiskMetadata := methods.NewSetDiskMetadataMethod(computeServiceBuilder, volumeServiceBuilder, logger)
			err := setDiskMetadata.SetDiskMetadata(diskCID, diskMeta)
			Expect(err).NotTo(HaveOccurred())
		})

		It("fails on metadata set", func() {
			volumeService = new(volumefakes.FakeVolumeService)
			volumeServiceBuilder.BuildReturns(volumeService, nil)
			volume := volumes.Volume{
				ID: volumeId1,
				Metadata: map[string]string{
					key1: value1,
					key2: value2,
				},
			}
			volumeService.GetVolumeReturns(&volume, nil)
			diskCID := apiv1.NewDiskCID(volumeId1)
			valid := map[string]interface{}{
				key1: value1,
				key2: value2,
			}
			diskMeta := apiv1.NewDiskMeta(valid)
			setDiskMetadata := methods.NewSetDiskMetadataMethod(computeServiceBuilder, volumeServiceBuilder, logger)
			volumeService.SetDiskMetadataReturns(errors.New("boom"))
			err := setDiskMetadata.SetDiskMetadata(diskCID, diskMeta)
			Expect(err.Error()).To(Equal("set_disk_metadata: Failed to set metadata for volume ID vol1-id: boom"))
		})
	})

})
