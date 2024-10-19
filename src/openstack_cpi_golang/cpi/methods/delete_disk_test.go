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

var _ = Describe("DeleteDisk", func() {

	var cpiConfig config.CpiConfig
	var logger utilsfakes.FakeLogger
	var volumeService volumefakes.FakeVolumeService
	var volumeServiceBuilder volumefakes.FakeVolumeServiceBuilder

	Context("DeleteDisk", func() {
		BeforeEach(func() {
			volumeServiceBuilder = volumefakes.FakeVolumeServiceBuilder{}
			volumeService = volumefakes.FakeVolumeService{}

			volumeServiceBuilder.BuildReturns(&volumeService, nil)
			volumeService.GetVolumeReturns(&volumes.Volume{ID: "some-disk-cid", Status: "available"}, nil)
			volumeService.DeleteVolumeReturns(nil)
			volumeService.WaitForVolumeToBecomeStatusReturns(nil)
			cpiConfig = config.CpiConfig{}
			cpiConfig.Cloud.Properties.Openstack = config.OpenstackConfig{}

			logger = utilsfakes.FakeLogger{}
		})

		It("returns an error if the volume service cannot be retrieved", func() {
			volumeServiceBuilder.BuildReturns(nil, errors.New("boom"))

			err := methods.NewDeleteDiskMethod(
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).DeleteDisk(
				apiv1.NewDiskCID("some-disk-cid"),
			)

			Expect(err.Error()).To(Equal("failed to create volume service: boom"))
		})

		It("creates the volume service", func() {
			err := methods.NewDeleteDiskMethod(
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).DeleteDisk(
				apiv1.NewDiskCID("some-disk-cid"),
			)

			Expect(err).ToNot(HaveOccurred())
			Expect(volumeServiceBuilder.BuildCallCount()).To(Equal(1))
		})

		It("returns an error if the volume cannot be retrieved", func() {
			volumeService.GetVolumeReturns(&volumes.Volume{}, errors.New("some_error_while_getting_volume"))

			err := methods.NewDeleteDiskMethod(
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).DeleteDisk(
				apiv1.NewDiskCID("some-disk-cid"),
			)

			Expect(err.Error()).To(Equal("delete disk: some_error_while_getting_volume"))
		})

		It("returns an error if volume is not in status available", func() {
			volumeService.GetVolumeReturns(&volumes.Volume{ID: "some-disk-cid", Status: "not_available"}, nil)

			err := methods.NewDeleteDiskMethod(
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).DeleteDisk(
				apiv1.NewDiskCID("some-disk-cid"),
			)

			Expect(err.Error()).To(Equal("cannot delete volume some-disk-cid, state is not_available"))
		})

		It("returns an error if the volume cannot be deleted", func() {
			volumeService.DeleteVolumeReturns(errors.New("some_error_while_deleting_volume"))

			err := methods.NewDeleteDiskMethod(
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).DeleteDisk(
				apiv1.NewDiskCID("some-disk-cid"),
			)

			Expect(err.Error()).To(Equal("delete disk: some_error_while_deleting_volume"))
		})

		It("fails while waiting for the volume to become deleted", func() {
			volumeService.WaitForVolumeToBecomeStatusReturns(errors.New("some_error_while_waiting_for_volume"))

			err := methods.NewDeleteDiskMethod(
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).DeleteDisk(
				apiv1.NewDiskCID("some-disk-cid"),
			)

			Expect(volumeService.WaitForVolumeToBecomeStatusCallCount()).To(Equal(1))
			Expect(err.Error()).To(Equal("delete disk: some_error_while_waiting_for_volume"))
		})

		It("deletes the volume", func() {
			err := methods.NewDeleteDiskMethod(
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).DeleteDisk(
				apiv1.NewDiskCID("some-disk-cid"),
			)

			Expect(volumeService.DeleteVolumeCallCount()).To(Equal(1))
			Expect(err).ToNot(HaveOccurred())
		})

		Context("when volume is not found. Skipping.", func() {
			BeforeEach(func() {
				volumeService.GetVolumeReturns(&volumes.Volume{}, nil)
			})

			It("issues a logger message", func() {
				_ = methods.NewDeleteDiskMethod(
					&volumeServiceBuilder,
					cpiConfig,
					&logger,
				).DeleteDisk(
					apiv1.NewDiskCID("some-disk-cid"),
				)
				firstLoggerInfo, secondLoggerInfo, _ := logger.InfoArgsForCall(0)

				Expect(logger.InfoCallCount()).To(Equal(1))
				Expect(firstLoggerInfo).To(Equal("volume %s not found. Skipping."))
				Expect(secondLoggerInfo).To(Equal("some-disk-cid"))
			})
		})
	})
})
