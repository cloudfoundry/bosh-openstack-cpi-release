package methods_test

import (
	"errors"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/methods"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/volume/volumefakes"
	"github.com/gophercloud/gophercloud"
	"github.com/gophercloud/gophercloud/openstack/blockstorage/v3/volumes"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("HasDiskMethod", func() {

	var volumeServicebuilder volumefakes.FakeVolumeServiceBuilder
	var volumeService volumefakes.FakeVolumeService
	var logger utilsfakes.FakeLogger

	Context("HasDisk", func() {
		BeforeEach(func() {
			volumeServicebuilder = volumefakes.FakeVolumeServiceBuilder{}
			logger = utilsfakes.FakeLogger{}

			volumeServicebuilder.BuildReturns(&volumeService, nil)
			volumeService.GetVolumeReturns(&volumes.Volume{ID: "123-456"}, nil)

		})

		It("creates the volume service", func() {
			_, _ = methods.NewHasDiskMethod(
				&volumeServicebuilder,
				&logger,
			).HasDisk(
				apiv1.NewDiskCID("disk-id"),
			)

			Expect(volumeServicebuilder.BuildCallCount()).To(Equal(1))
		})

		It("returns an error and false if the volume service cannot be retrieved", func() {
			volumeServicebuilder.BuildReturns(nil, errors.New("boom"))

			exists, err := methods.NewHasDiskMethod(
				&volumeServicebuilder,
				&logger,
			).HasDisk(
				apiv1.NewDiskCID("disk-id"),
			)

			Expect(exists).To(Equal(false))
			Expect(err.Error()).To(Equal("has_disk: boom"))
		})

		It("returns false and no error if GetVolume fails with notFound", func() {
			testError := gophercloud.ErrDefault404{
				ErrUnexpectedResponseCode: gophercloud.ErrUnexpectedResponseCode{Actual: 404},
			}
			volumeService.GetVolumeReturns(nil, testError)

			exists, err := methods.NewHasDiskMethod(
				&volumeServicebuilder,
				&logger,
			).HasDisk(
				apiv1.NewDiskCID("disk-id"),
			)

			Expect(exists).To(Equal(false))
			Expect(err).ToNot(HaveOccurred())
		})

		It("returns false and error if GetVolume fails", func() {
			volumeService.GetVolumeReturns(nil, errors.New("boom"))

			exists, err := methods.NewHasDiskMethod(
				&volumeServicebuilder,
				&logger,
			).HasDisk(
				apiv1.NewDiskCID("disk-id"),
			)

			Expect(exists).To(Equal(false))
			Expect(err).To(HaveOccurred())
		})

		It("returns false if no error and volume id is nil", func() {
			volumeService.GetVolumeReturns(&volumes.Volume{ID: ""}, nil)

			exists, err := methods.NewHasDiskMethod(
				&volumeServicebuilder,
				&logger,
			).HasDisk(
				apiv1.NewDiskCID("disk-id"),
			)

			Expect(exists).To(Equal(false))
			Expect(err).ToNot(HaveOccurred())
		})

		It("returns true if no error and volume id is not nil", func() {
			volumeService.GetVolumeReturns(&volumes.Volume{ID: "123-456"}, nil)

			exists, err := methods.NewHasDiskMethod(
				&volumeServicebuilder,
				&logger,
			).HasDisk(
				apiv1.NewDiskCID("disk-id"),
			)

			Expect(exists).To(Equal(true))
			Expect(err).ToNot(HaveOccurred())
		})
	})
})
