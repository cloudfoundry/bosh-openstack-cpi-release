package methods_test

import (
	"errors"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/methods"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/volume/volumefakes"
	"github.com/gophercloud/gophercloud/openstack/blockstorage/v3/volumes"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("NewResizeDiskMethod", func() {

	var volumeService volumefakes.FakeVolumeService
	var volumeServiceBuilder volumefakes.FakeVolumeServiceBuilder
	var logger utilsfakes.FakeLogger
	var cpiConfig config.CpiConfig

	Context("ResizeDisk", func() {
		newSizeSmaller := 4000
		newSizeEqual := 5000
		newSizeLarger := 6000
		diskCID := apiv1.NewDiskCID("test-disk-cid")
		attachmentNotNull := []volumes.Attachment{{AttachmentID: "test-attachment-id"}}
		volumeWithAttachment := &volumes.Volume{ID: "test-disk-cid", Size: 5, Attachments: attachmentNotNull}
		volumeWithoutAttachment := &volumes.Volume{ID: "test-disk-cid", Size: 5}

		BeforeEach(func() {
			volumeServiceBuilder = volumefakes.FakeVolumeServiceBuilder{}
			volumeService = volumefakes.FakeVolumeService{}
			logger = utilsfakes.FakeLogger{}
			cpiConfig = config.CpiConfig{}

			volumeServiceBuilder.BuildReturns(&volumeService, nil)
			volumeService.GetVolumeReturns(volumeWithoutAttachment, nil)
			volumeService.ExtendVolumeSizeReturns(nil)
			volumeService.WaitForVolumeToBecomeStatusReturns(nil)
		})

		It("creates the volume service", func() {
			err := methods.NewResizeDiskMethod(
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).ResizeDisk(
				diskCID,
				newSizeLarger,
			)

			Expect(err).ToNot(HaveOccurred())
			Expect(volumeServiceBuilder.BuildCallCount()).To(Equal(1))
		})

		It("returns an error if the volume service cannot be retrieved", func() {
			volumeServiceBuilder.BuildReturns(nil, errors.New("boom"))

			err := methods.NewResizeDiskMethod(
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).ResizeDisk(
				diskCID,
				newSizeLarger,
			)

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("failed to create volume service: boom"))
		})

		It("gets a volume back", func() {
			err := methods.NewResizeDiskMethod(
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).ResizeDisk(
				diskCID,
				newSizeLarger,
			)

			Expect(err).ToNot(HaveOccurred())
			Expect(volumeService.GetVolumeCallCount()).To(Equal(1))
		})

		It("returns an error if the volume cannot be retrieved", func() {
			volumeService.GetVolumeReturns(nil, errors.New("boom"))

			err := methods.NewResizeDiskMethod(
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).ResizeDisk(
				diskCID,
				newSizeLarger,
			)

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("cannot resize volume because volume with id test-disk-cid not found, error: boom"))
		})

		It("returns nil because new and current volumesize are the same", func() {
			err := methods.NewResizeDiskMethod(
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).ResizeDisk(
				diskCID,
				newSizeEqual,
			)

			Expect(err).ToNot(HaveOccurred())
			Expect(volumeService.ExtendVolumeSizeCallCount()).To(Equal(0))
			arg1, arg2, _ := logger.InfoArgsForCall(1)
			Expect(arg1).To(Equal("resize_disk"))
			Expect(arg2).To(Equal("Skipping resize of disk test-disk-cid because current value 5 GiB is equal new value 5 GiB"))
			Expect(volumeService.GetVolumeCallCount()).To(Equal(1))
		})

		It("returns error because new volumesize is smaller than the current one", func() {
			err := methods.NewResizeDiskMethod(
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).ResizeDisk(
				diskCID,
				newSizeSmaller,
			)

			Expect(err).To(HaveOccurred())
			Expect(volumeService.ExtendVolumeSizeCallCount()).To(Equal(0))
			Expect(err.Error()).To(Equal("cannot resize volume to a smaller size from 5 GiB to 4 GiB"))
		})

		It("returns error because volume.Attachment is not nil", func() {
			volumeService.GetVolumeReturns(volumeWithAttachment, nil)
			err := methods.NewResizeDiskMethod(
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).ResizeDisk(
				diskCID,
				newSizeLarger,
			)

			Expect(err).To(HaveOccurred())
			Expect(volumeService.ExtendVolumeSizeCallCount()).To(Equal(0))
			Expect(err.Error()).To(Equal("cannot resize volume test-disk-cid due to attachments"))
		})

		It("extends the volume size successfully", func() {
			err := methods.NewResizeDiskMethod(
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).ResizeDisk(
				diskCID,
				newSizeLarger,
			)

			Expect(err).ToNot(HaveOccurred())
			Expect(volumeService.ExtendVolumeSizeCallCount()).To(Equal(1))
			arg1, arg2, _ := logger.InfoArgsForCall(2)
			Expect(arg1).To(Equal("resize_disk"))
			Expect(arg2).To(Equal("Resized volume test-disk-cid to 6 GiB"))
		})

		It("returns error because volume could not be extended", func() {
			volumeService.ExtendVolumeSizeReturns(errors.New("boom"))
			err := methods.NewResizeDiskMethod(
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).ResizeDisk(
				diskCID,
				newSizeLarger,
			)

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("failed to resize volume test-disk-cid: boom"))
		})

		It("waits for volume to become available successfully", func() {
			err := methods.NewResizeDiskMethod(
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).ResizeDisk(
				diskCID,
				newSizeLarger,
			)

			Expect(err).ToNot(HaveOccurred())
			Expect(volumeService.WaitForVolumeToBecomeStatusCallCount()).To(Equal(1))
			arg1, arg2, _ := logger.InfoArgsForCall(2)
			Expect(arg1).To(Equal("resize_disk"))
			Expect(arg2).To(Equal("Resized volume test-disk-cid to 6 GiB"))
		})

		It("returns error while waiting for volume to be extended", func() {
			volumeService.WaitForVolumeToBecomeStatusReturns(errors.New("boom"))
			err := methods.NewResizeDiskMethod(
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).ResizeDisk(
				diskCID,
				newSizeLarger,
			)

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("failed while waiting on resizing volume test-disk-cid: boom"))
		})
	})
})
