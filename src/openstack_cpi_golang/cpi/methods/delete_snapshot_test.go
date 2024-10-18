package methods_test

import (
	"errors"
	"time"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/methods"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/volume/volumefakes"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("DeleteSnapshotMethod Unit Tests", func() {
	var (
		volumeServiceBuilder *volumefakes.FakeVolumeServiceBuilder
		volumeService        *volumefakes.FakeVolumeService
		logger               *utilsfakes.FakeLogger
		cpiConfig            config.CpiConfig
		deleteSnapshot       methods.DeleteSnapshotMethod
		snapshotCID          apiv1.SnapshotCID
	)

	BeforeEach(func() {
		volumeServiceBuilder = new(volumefakes.FakeVolumeServiceBuilder)
		volumeService = new(volumefakes.FakeVolumeService)
		logger = new(utilsfakes.FakeLogger)

		volumeServiceBuilder.BuildReturns(volumeService, nil)
		snapshotCID = apiv1.NewSnapshotCID("snap1-id")

		cpiConfig = config.CpiConfig{}
		deleteSnapshot = methods.NewDeleteSnapshotMethod(volumeServiceBuilder, cpiConfig, logger)
	})

	It("fails on volume service builder", func() {
		volumeServiceBuilder.BuildReturns(nil, errors.New("boom"))
		err := deleteSnapshot.DeleteSnapshot(snapshotCID)
		Expect(err.Error()).To(Equal("deleteSnapshot: Failed to get volume service: boom"))
	})

	It("fails to delete snapshot", func() {
		volumeService.DeleteSnapshotReturns(errors.New("boom"))
		err := deleteSnapshot.DeleteSnapshot(snapshotCID)
		Expect(err.Error()).To(Equal("deleteSnapshot: Failed to delete snapshot ID snap1-id: boom"))
	})

	It("fails to wait for snapshot to be deleted", func() {
		volumeService.WaitForSnapshotToBecomeStatusReturns(errors.New("boom"))
		err := deleteSnapshot.DeleteSnapshot(snapshotCID)
		Expect(err.Error()).To(Equal("deleteSnapshot: Failed while waiting for snapshot ID snap1-id to be deleted: boom"))
	})

	It("successfully deletes snapshot", func() {
		err := deleteSnapshot.DeleteSnapshot(snapshotCID)
		Expect(err).ToNot(HaveOccurred())

		Expect(volumeService.DeleteSnapshotCallCount()).To(Equal(1))
		Expect(volumeService.DeleteSnapshotArgsForCall(0)).To(Equal("snap1-id"))

		Expect(volumeService.WaitForSnapshotToBecomeStatusCallCount()).To(Equal(1))
		snapshotID, timeout, status := volumeService.WaitForSnapshotToBecomeStatusArgsForCall(0)
		Expect(snapshotID).To(Equal("snap1-id"))
		Expect(timeout).To(Equal(time.Duration(cpiConfig.OpenStackConfig().StateTimeOut) * time.Second))
		Expect(status).To(Equal("deleted"))
	})
})
