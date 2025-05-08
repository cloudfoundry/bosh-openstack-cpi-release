package image_test

import (
	"fmt"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/image"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/image/imagefakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("lightStemcellCreator", func() {
	Context("Create", func() {
		It("returns the stemcell id of an existing image", func() {
			imageServiceClient := imagefakes.FakeImageService{}
			imageServiceClient.GetImageReturns("1234", nil)
			subject := image.NewLightStemcellCreator(config.OpenstackConfig{})
			imageID, err := subject.Create(&imageServiceClient, properties.CreateStemcell{})

			Expect(err).ToNot(HaveOccurred())
			Expect(imageID).To(Equal("1234"))
		})

		It("returns an error if no image can be found", func() {
			imageServiceClient := imagefakes.FakeImageService{}
			imageServiceClient.GetImageReturns("", fmt.Errorf("boom"))
			subject := image.NewLightStemcellCreator(config.OpenstackConfig{})
			imageID, err := subject.Create(&imageServiceClient, properties.CreateStemcell{})

			Expect(err.Error()).To(Equal("failed to retrieve image: boom"))
			Expect(imageID).To(Equal(""))
		})

		It("gets an image via imageID", func() {
			imageServiceClient := imagefakes.FakeImageService{}

			subject := image.NewLightStemcellCreator(config.OpenstackConfig{})
			_, _ = subject.Create(&imageServiceClient, properties.CreateStemcell{ImageID: "123-456"}) //nolint:errcheck

			imageID := imageServiceClient.GetImageArgsForCall(0)
			Expect(imageID).To(Equal("123-456"))
		})
	})
})
