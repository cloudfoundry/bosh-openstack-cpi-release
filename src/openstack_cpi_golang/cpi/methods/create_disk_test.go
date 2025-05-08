package methods_test

import (
	"errors"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute/computefakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/methods"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/volume/volumefakes"
	"github.com/gophercloud/gophercloud"
	"github.com/gophercloud/gophercloud/openstack/blockstorage/v3/volumes"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/servers"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("CreateDisk", func() {

	var cpiConfig config.CpiConfig
	var logger utilsfakes.FakeLogger
	var computeService computefakes.FakeComputeService
	var volumeService volumefakes.FakeVolumeService
	var volumeServiceBuilder volumefakes.FakeVolumeServiceBuilder
	var computeServiceBuilder computefakes.FakeComputeServiceBuilder
	var jsonStr string
	var size int

	Context("CreateDisk", func() {
		BeforeEach(func() {
			computeServiceBuilder = computefakes.FakeComputeServiceBuilder{}
			volumeServiceBuilder = volumefakes.FakeVolumeServiceBuilder{}
			computeService = computefakes.FakeComputeService{}
			volumeService = volumefakes.FakeVolumeService{}

			computeServiceBuilder.BuildReturns(&computeService, nil)
			volumeServiceBuilder.BuildReturns(&volumeService, nil)
			computeService.GetServerReturns(&servers.Server{ID: "123-456"}, nil)
			volumeService.CreateVolumeReturns(&volumes.Volume{ID: "789-size12"}, nil)
			volumeService.WaitForVolumeToBecomeStatusReturns(nil)
			cpiConfig = config.CpiConfig{}
			cpiConfig.Cloud.Properties.Openstack = config.OpenstackConfig{IgnoreServerAvailabilityZone: true}

			logger = utilsfakes.FakeLogger{}
			size = 1025

			jsonStr = `{
					"type": "vmware"
				}`
		})

		It("returns an error if the volume size is below 1 GiB", func() {
			size = 1023

			_, err := methods.NewCreateDiskMethod(
				&computeServiceBuilder,
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).CreateDisk(
				size,
				apiv1.CloudPropsImpl{RawMessage: []byte(jsonStr)},
				&apiv1.VMCID{},
			)

			Expect(err.Error()).To(Equal("minimum disk size is 1 GiB"))
		})

		It("creates the volume service", func() {
			_, _ = methods.NewCreateDiskMethod( //nolint:errcheck
				&computeServiceBuilder,
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).CreateDisk(
				size,
				apiv1.CloudPropsImpl{RawMessage: []byte(jsonStr)},
				&apiv1.VMCID{},
			)

			Expect(volumeServiceBuilder.BuildCallCount()).To(Equal(1))
		})

		It("returns an error if the volume service cannot be retrieved", func() {
			volumeServiceBuilder.BuildReturns(nil, errors.New("boom"))

			diskCID, err := methods.NewCreateDiskMethod(
				&computeServiceBuilder,
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).CreateDisk(
				size,
				apiv1.CloudPropsImpl{RawMessage: []byte(jsonStr)},
				&apiv1.VMCID{},
			)

			Expect(err.Error()).To(Equal("failed to create volume service: boom"))
			Expect(diskCID).To(Equal(apiv1.DiskCID{}))
		})

		It("creates the compute service", func() {
			_, _ = methods.NewCreateDiskMethod( //nolint:errcheck
				&computeServiceBuilder,
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).CreateDisk(
				size,
				apiv1.CloudPropsImpl{RawMessage: []byte(jsonStr)},
				&apiv1.VMCID{},
			)

			Expect(computeServiceBuilder.BuildCallCount()).To(Equal(1))
		})

		It("returns an error if the compute service cannot be retrieved", func() {
			computeServiceBuilder.BuildReturns(nil, errors.New("boom"))

			diskCID, err := methods.NewCreateDiskMethod(
				&computeServiceBuilder,
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).CreateDisk(
				size,
				apiv1.CloudPropsImpl{RawMessage: []byte(jsonStr)},
				&apiv1.VMCID{},
			)

			Expect(err.Error()).To(Equal("failed to create compute service: boom"))
			Expect(diskCID).To(Equal(apiv1.DiskCID{}))
		})

		Context("when ignore_server_availability_zone is false", func() {
			BeforeEach(func() {
				computeService.GetServerAZReturns("AZ", nil)
				cpiConfig.Cloud.Properties.Openstack = config.OpenstackConfig{IgnoreServerAvailabilityZone: false}
			})

			It("gets the server availability zone", func() {
				_, _ = methods.NewCreateDiskMethod( //nolint:errcheck
					&computeServiceBuilder,
					&volumeServiceBuilder,
					cpiConfig,
					&logger,
				).CreateDisk(
					size,
					apiv1.CloudPropsImpl{RawMessage: []byte(jsonStr)},
					&apiv1.VMCID{},
				)

				_, _, az := volumeService.CreateVolumeArgsForCall(0)

				Expect(computeService.GetServerAZCallCount()).To(Equal(1))
				Expect(az).To(Equal("AZ"))
			})

			It("returns an error if GetServerAZ failed", func() {
				computeService.GetServerAZReturns("", errors.New("boom"))

				diskCID, err := methods.NewCreateDiskMethod(
					&computeServiceBuilder,
					&volumeServiceBuilder,
					cpiConfig,
					&logger,
				).CreateDisk(
					size,
					apiv1.CloudPropsImpl{RawMessage: []byte(jsonStr)},
					&apiv1.VMCID{},
				)

				Expect(err.Error()).To(Equal("create_disk: boom"))
				Expect(diskCID).To(Equal(apiv1.DiskCID{}))
			})
		})

		Context("when ignore_server_availability_zone is true", func() {
			It("does not get the server availability zone", func() {
				_, _ = methods.NewCreateDiskMethod( //nolint:errcheck
					&computeServiceBuilder,
					&volumeServiceBuilder,
					cpiConfig,
					&logger,
				).CreateDisk(
					size,
					apiv1.CloudPropsImpl{RawMessage: []byte(jsonStr)},
					&apiv1.VMCID{},
				)

				Expect(computeService.GetServerAZCallCount()).To(Equal(0))
			})
		})

		It("creates the volume", func() {
			_, _ = methods.NewCreateDiskMethod( //nolint:errcheck
				&computeServiceBuilder,
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).CreateDisk(
				size,
				apiv1.CloudPropsImpl{RawMessage: []byte(jsonStr)},
				&apiv1.VMCID{},
			)

			size, _, _ := volumeService.CreateVolumeArgsForCall(0)
			Expect(size).To(Equal(2))
			Expect(volumeService.CreateVolumeCallCount()).To(Equal(1))
		})

		It("returns an error if CreateVolume fails", func() {
			volumeService.CreateVolumeReturns(nil, errors.New("boom"))

			diskCID, err := methods.NewCreateDiskMethod(
				&computeServiceBuilder,
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).CreateDisk(
				size,
				apiv1.CloudPropsImpl{RawMessage: []byte(jsonStr)},
				&apiv1.VMCID{},
			)

			Expect(err.Error()).To(Equal("failed to create volume: boom"))
			Expect(diskCID).To(Equal(apiv1.DiskCID{}))
		})

		It("returns an error if GetServer fails", func() {
			computeService.GetServerReturns(nil, errors.New("boom"))

			diskCID, err := methods.NewCreateDiskMethod(
				&computeServiceBuilder,
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).CreateDisk(
				size,
				apiv1.CloudPropsImpl{RawMessage: []byte(jsonStr)},
				&apiv1.VMCID{},
			)

			Expect(err.Error()).To(Equal("create_disk: boom"))
			Expect(diskCID).To(Equal(apiv1.DiskCID{}))
		})

		It("does not returns an error if no server can be retrieved", func() {
			var errDefault404 gophercloud.ErrDefault404
			computeService.GetServerReturns(nil, errDefault404)

			diskCID, err := methods.NewCreateDiskMethod(
				&computeServiceBuilder,
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).CreateDisk(
				size,
				apiv1.CloudPropsImpl{RawMessage: []byte(jsonStr)},
				&apiv1.VMCID{},
			)

			Expect(err).To(BeNil())
			Expect(diskCID).To(Equal(apiv1.DiskCID{}))
		})

		It("fails while waiting for the volume to become available", func() {
			volumeService.WaitForVolumeToBecomeStatusReturns(errors.New("some_error_while_waiting_for_volume"))

			diskCID, err := methods.NewCreateDiskMethod(
				&computeServiceBuilder,
				&volumeServiceBuilder,
				cpiConfig,
				&logger,
			).CreateDisk(
				size,
				apiv1.CloudPropsImpl{RawMessage: []byte(jsonStr)},
				&apiv1.VMCID{},
			)

			Expect(volumeService.WaitForVolumeToBecomeStatusCallCount()).To(Equal(1))
			Expect(err.Error()).To(Equal("create disk: some_error_while_waiting_for_volume"))
			Expect(diskCID).To(Equal(apiv1.DiskCID{}))
		})
	})
})
