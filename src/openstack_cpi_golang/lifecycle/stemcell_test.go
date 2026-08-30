//go:build lifecycle

package lifecycle_test

import (
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/gophercloud/gophercloud"
	"github.com/gophercloud/gophercloud/openstack"
	"github.com/gophercloud/gophercloud/openstack/imageservice/v2/images"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Stemcell lifecycle", func() {
	cfg := func() config.CpiConfig { return baseConfig() }

	Context("heavy stemcell (Glance upload)", func() {
		It("uploads an image with the expected Glance properties", func() {
			// Inspect the suite stemcell rather than paying for a second upload.
			img := inspectImage(cfg(), stemcellID)

			Expect(img.Name).To(Equal(suiteManifest.Name + "/" + suiteManifest.Version))
			Expect(img.Visibility).To(Equal(images.ImageVisibilityPrivate))
			Expect(img.Properties).To(HaveKeyWithValue("os_distro", "ubuntu"))
		})

		It("deletes a heavy stemcell", func() {
			id, cpiErr := createStemcell(cfg(), stemcellImagePath(), suiteManifest.CloudProperties)
			Expect(cpiErr).To(BeNil())
			Expect(id).ToNot(BeEmpty())

			Expect(deleteStemcell(cfg(), id)).To(BeNil())

			_, err := images.Get(imageClient(cfg()), id).Extract()
			Expect(err).To(HaveOccurred(), "image %s should be gone after delete_stemcell", id)
		})
	})

	Context("light stemcell", func() {
		It("returns the referenced image id for a light stemcell", func() {
			id, cpiErr := createStemcell(cfg(), "/dev/null", map[string]interface{}{"image_id": stemcellID})
			Expect(cpiErr).To(BeNil())
			Expect(id).To(Equal(stemcellID))
		})

		It("fails if the referenced image does not exist", func() {
			_, cpiErr := createStemcell(cfg(), "/dev/null", map[string]interface{}{"image_id": "non-existing-id"})
			Expect(cpiErr).ToNot(BeNil())
		})

		It("boots a VM from a light stemcell", func() {
			lightID, cpiErr := createStemcell(cfg(), "/dev/null", map[string]interface{}{"image_id": stemcellID})
			Expect(cpiErr).To(BeNil())

			vmID, cpiErr := createVM(cfg(), lightID, defaultResourcePool(), dynamicNetwork(), nil, nil)
			Expect(cpiErr).To(BeNil())
			Expect(vmID).ToNot(BeEmpty())

			exists, cpiErr := hasVM(cfg(), vmID)
			Expect(cpiErr).To(BeNil())
			Expect(exists).To(BeTrue())
		})
	})
})

func imageClient(cfg config.CpiConfig) *gophercloud.ServiceClient {
	GinkgoHelper()
	provider, err := openstack.AuthenticatedClient(cfg.OpenStackConfig().AuthOptions())
	Expect(err).NotTo(HaveOccurred())
	client, err := openstack.NewImageServiceV2(provider, gophercloud.EndpointOpts{Region: cfg.OpenStackConfig().Region})
	Expect(err).NotTo(HaveOccurred())
	return client
}

func inspectImage(cfg config.CpiConfig, id string) *images.Image {
	GinkgoHelper()
	img, err := images.Get(imageClient(cfg), id).Extract()
	Expect(err).NotTo(HaveOccurred())
	return img
}
