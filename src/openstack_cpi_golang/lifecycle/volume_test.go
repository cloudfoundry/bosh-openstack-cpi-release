//go:build lifecycle

package lifecycle_test

import (
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/gophercloud/gophercloud"
	"github.com/gophercloud/gophercloud/openstack"
	"github.com/gophercloud/gophercloud/openstack/blockstorage/v3/volumes"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

// A single VM is shared across the specs because create_disk needs a VM to
// derive the availability zone.
var _ = Describe("Volume lifecycle", Ordered, func() {
	var vmID string

	BeforeAll(func() {
		var cpiErr *cpiError
		vmID, cpiErr = createVM(baseConfig(), stemcellID, defaultResourcePool(), dynamicNetwork(), nil, nil)
		Expect(cpiErr).To(BeNil())
		Expect(vmID).ToNot(BeEmpty())
	})

	Context("Cinder volume types", func() {
		It("uses the default Cinder type when neither global nor per-disk type is set", func() {
			cfg := baseConfig(withDefaultVolumeType(""))
			diskID, cpiErr := createDisk(cfg, 2048, nil, vmID)
			Expect(cpiErr).To(BeNil())

			exists, cpiErr := hasDisk(cfg, diskID)
			Expect(cpiErr).To(BeNil())
			Expect(exists).To(BeTrue())
			Expect(inspectVolume(cfg, diskID).VolumeType).ToNot(BeEmpty())
		})

		It("uses the type set in cloud_properties", func() {
			cfg := baseConfig(withDefaultVolumeType(""))
			volType := mustEnv("BOSH_OPENSTACK_VOLUME_TYPE")
			diskID, cpiErr := createDisk(cfg, 2048, map[string]interface{}{"type": volType}, vmID)
			Expect(cpiErr).To(BeNil())
			Expect(inspectVolume(cfg, diskID).VolumeType).To(Equal(volType))
		})

		It("prefers the per-disk type over the global default_volume_type", func() {
			cfg := baseConfig(withDefaultVolumeType("type-to-override"))
			volType := mustEnv("BOSH_OPENSTACK_VOLUME_TYPE")
			diskID, cpiErr := createDisk(cfg, 2048, map[string]interface{}{"type": volType}, vmID)
			Expect(cpiErr).To(BeNil())
			Expect(inspectVolume(cfg, diskID).VolumeType).To(Equal(volType))
		})

		It("uses the global default_volume_type when no per-disk type is set", func() {
			volType := mustEnv("BOSH_OPENSTACK_VOLUME_TYPE")
			cfg := baseConfig(withDefaultVolumeType(volType))
			diskID, cpiErr := createDisk(cfg, 2048, nil, vmID)
			Expect(cpiErr).To(BeNil())
			Expect(inspectVolume(cfg, diskID).VolumeType).To(Equal(volType))
		})
	})

	Context("disk operations", func() {
		It("sets disk metadata", func() {
			cfg := baseConfig()
			diskID, cpiErr := createDisk(cfg, 2048, nil, vmID)
			Expect(cpiErr).To(BeNil())

			Expect(setDiskMetadata(cfg, diskID, map[string]interface{}{
				"deployment": "some-deployment",
				"job":        "some-job",
				"index":      "0",
				"some_key":   "some_value",
			})).To(BeNil())

			Expect(inspectVolume(cfg, diskID).Metadata).To(HaveKeyWithValue("some_key", "some_value"))
		})

		It("creates and deletes a snapshot", func() {
			cfg := baseConfig()
			diskID, cpiErr := createDisk(cfg, 2048, nil, vmID)
			Expect(cpiErr).To(BeNil())

			snapshotID, cpiErr := snapshotDisk(cfg, diskID, map[string]interface{}{
				"deployment": "some-deployment",
				"job":        "some-job",
				"index":      "0",
			})
			Expect(cpiErr).To(BeNil())
			Expect(snapshotID).ToNot(BeEmpty())

			Expect(deleteSnapshot(cfg, snapshotID)).To(BeNil())
		})

		It("resizes a disk", func() {
			cfg := baseConfig()
			diskID, cpiErr := createDisk(cfg, 2048, nil, vmID)
			Expect(cpiErr).To(BeNil())

			Expect(resizeDisk(cfg, diskID, 4096)).To(BeNil())
			Expect(inspectVolume(cfg, diskID).Size).To(Equal(4))
		})
	})
})

func blockStorageClient(cfg config.CpiConfig) *gophercloud.ServiceClient {
	GinkgoHelper()
	provider, err := openstack.AuthenticatedClient(cfg.OpenStackConfig().AuthOptions())
	Expect(err).NotTo(HaveOccurred())
	client, err := openstack.NewBlockStorageV3(provider, gophercloud.EndpointOpts{Region: cfg.OpenStackConfig().Region})
	Expect(err).NotTo(HaveOccurred())
	return client
}

func inspectVolume(cfg config.CpiConfig, id string) *volumes.Volume {
	GinkgoHelper()
	vol, err := volumes.Get(blockStorageClient(cfg), id).Extract()
	Expect(err).NotTo(HaveOccurred())
	return vol
}
