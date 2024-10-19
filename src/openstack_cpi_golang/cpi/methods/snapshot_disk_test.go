package methods_test

import (
	"errors"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/gophercloud/gophercloud/openstack/blockstorage/v3/snapshots"
	"github.com/gophercloud/gophercloud/openstack/blockstorage/v3/volumes"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/methods"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/volume/volumefakes"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("SnapshotDisk Unit Tests", func() {

	var volumeServiceBuilder *volumefakes.FakeVolumeServiceBuilder
	var volumeService *volumefakes.FakeVolumeService
	var logger *utilsfakes.FakeLogger
	var cpiConfig config.CpiConfig
	var volumeCid = apiv1.NewDiskCID("vol1-id")
	var metadata apiv1.DiskMeta
	var snapshotDisk methods.SnapshotDiskMethod
	var volume volumes.Volume
	var snapshot snapshots.Snapshot

	Context("setting disk metadata", func() {

		BeforeEach(func() {
			volumeServiceBuilder = new(volumefakes.FakeVolumeServiceBuilder)
			volumeService = new(volumefakes.FakeVolumeService)
			logger = new(utilsfakes.FakeLogger)

			volumeServiceBuilder.BuildReturns(volumeService, nil)
			volume = volumes.Volume{
				ID: "vol1-id",
				Attachments: []volumes.Attachment{
					{Device: "dev1/dev2/dev3", ServerID: "server1", VolumeID: "vol1-id"},
					{Device: "dev5/dev6/dev7", ServerID: "server2", VolumeID: "vol1-id"},
				},
			}
			volumeService.GetVolumeReturns(&volume, nil)

			diskMeta := map[string]interface{}{
				"deployment":    "deployment",
				"job":           "job",
				"index":         1,
				"test":          "test",
				"director_name": "director_name",
				"instance_id":   "instance_id",
			}
			metadata = apiv1.NewDiskMeta(diskMeta)

			snapshot = snapshots.Snapshot{
				ID: "snap1-id",
			}
			volumeService.CreateSnapshotReturns(&snapshot, nil)

			cpiConfig = config.CpiConfig{}
			snapshotDisk = methods.NewSnapshotDiskMethod(volumeServiceBuilder, cpiConfig, logger)
		})

		It("fails on volume service builder", func() {
			volumeServiceBuilder.BuildReturns(nil, errors.New("boom"))
			_, err := snapshotDisk.SnapshotDisk(volumeCid, metadata)
			Expect(err.Error()).To(Equal("snapShotDisk: Failed to get volume service: boom"))
		})

		It("fails on get volume", func() {
			volumeService.GetVolumeReturns(nil, errors.New("boom"))
			_, err := snapshotDisk.SnapshotDisk(volumeCid, metadata)
			Expect(err.Error()).To(Equal("snapShotDisk: Failed to get volume ID vol1-id: boom"))
		})

		It("fails to convert metadata to map[string]interface for MarshalJSON", func() {
			diskMeta := map[string]interface{}{
				"key1": func() {},
			}
			metadataFalse := apiv1.NewDiskMeta(diskMeta)
			_, err := snapshotDisk.SnapshotDisk(volumeCid, metadataFalse)
			Expect(err).To(MatchError(ContainSubstring("snapShotDisk: Failed to convert disk metadata")))
		})

		It("fails to create snapshot", func() {
			volumeService.CreateSnapshotReturns(nil, errors.New("boom"))
			_, err := snapshotDisk.SnapshotDisk(volumeCid, metadata)
			Expect(err).To(MatchError(ContainSubstring(("snapShotDisk: Failed to create snapshot"))))
		})

		It("creates snapshot", func() {
			snapshotCID, err := snapshotDisk.SnapshotDisk(volumeCid, metadata)

			volumeCidReturn, boolForce, snapShotName, joinedDescription, finalMetaDataMap := volumeService.CreateSnapshotArgsForCall(0)
			Expect(volumeCidReturn).To(Equal(volumeCid.AsString()))
			Expect(boolForce).To(BeTrue())
			Expect(snapShotName).To(ContainSubstring("snapshot-"))
			Expect(joinedDescription).To(Equal("deployment/job/1/dev3"))
			Expect(finalMetaDataMap).To(Equal(map[string]string{
				"deployment":     "deployment",
				"test":           "test",
				"director":       "director_name",
				"instance_id":    "instance_id",
				"instance_name":  "job/instance_id",
				"instance_index": "1",
			}))
			Expect(err).ToNot(HaveOccurred())
			Expect(snapshotCID.AsString()).To(Equal("snap1-id"))
		})

		It("fails to waitForSnapshotToBeAvailable", func() {
			volumeService.WaitForSnapshotToBecomeStatusReturns(errors.New("boom"))
			_, err := snapshotDisk.SnapshotDisk(volumeCid, metadata)
			Expect(err).To(MatchError(ContainSubstring("snapShotDisk: Failed while waiting for creating snapshot")))
		})
	})

})
