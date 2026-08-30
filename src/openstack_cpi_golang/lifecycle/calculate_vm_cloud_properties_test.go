//go:build lifecycle

package lifecycle_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("calculate_vm_cloud_properties", func() {
	It("maps VM resources to a matching instance_type", func() {
		props, cpiErr := calculateVMCloudProperties(baseConfig(), map[string]interface{}{
			"ram":                 512,
			"cpu":                 1,
			"ephemeral_disk_size": 2048,
		})
		Expect(cpiErr).To(BeNil())
		Expect(props).To(HaveKey("instance_type"))
		Expect(props["instance_type"]).ToNot(BeEmpty())
	})

	It("sets a custom root disk size when boot_from_volume is enabled", func() {
		props, cpiErr := calculateVMCloudProperties(baseConfig(withBootFromVolume()), map[string]interface{}{
			"ram":                 512,
			"cpu":                 1,
			"ephemeral_disk_size": 10240,
		})
		Expect(cpiErr).To(BeNil())
		Expect(props).To(HaveKey("instance_type"))
		Expect(props).To(HaveKey("root_disk"))
	})
})
