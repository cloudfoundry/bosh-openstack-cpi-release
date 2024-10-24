package image_test

import (
	"errors"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/image"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/image/imagefakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("heavyStemcellCreator", func() {
	var imageServiceClient imagefakes.FakeImageService
	var config = config.OpenstackConfig{}

	Context("Create", func() {

		BeforeEach(func() {
			imageServiceClient = imagefakes.FakeImageService{}
		})

		It("returns the ID of a created OpenStack image", func() {
			imageServiceClient.CreateImageReturns("1234", nil)

			imageID, err := image.NewHeavyStemcellCreator(config).
				Create(&imageServiceClient, properties.CreateStemcell{}, "root/image/path")

			Expect(err).ToNot(HaveOccurred())
			Expect(imageID).To(Equal("1234"))
		})

		It("returns an error if the OpenStack image creation fails", func() {
			imageServiceClient.CreateImageReturns("", errors.New("boom"))

			imageID, err := image.NewHeavyStemcellCreator(config).
				Create(&imageServiceClient, properties.CreateStemcell{}, "root/image/path")

			Expect(err.Error()).To(Equal("failed to create image: boom"))
			Expect(imageID).To(Equal(""))
		})

		It("returns an error if OpenStack image upload fails", func() {
			imageServiceClient.CreateImageReturns("1234", nil)
			imageServiceClient.UploadImageReturns(errors.New("boom"))

			imageID, err := image.NewHeavyStemcellCreator(config).
				Create(&imageServiceClient, properties.CreateStemcell{}, "root/image/path")

			Expect(err.Error()).To(Equal("failed to upload root image: boom"))
			Expect(imageID).To(Equal(""))
		})

		It("creates an OpenStack image", func() {
			imageServiceClient.CreateImageReturns("1234", nil)
			imageServiceClient.UploadImageReturns(nil)
			theCloudProps := properties.CreateStemcell{}

			_, _ = image.NewHeavyStemcellCreator(config).
				Create(&imageServiceClient, properties.CreateStemcell{}, "root/image/path")

			cloudProps, config := imageServiceClient.CreateImageArgsForCall(0)
			Expect(cloudProps).To(Equal(theCloudProps))
			Expect(config).To(Equal(config))
		})

		It("uploads the root.img file to a created OpenStack image", func() {
			imageServiceClient.CreateImageReturns("1234", nil)
			imageServiceClient.UploadImageReturns(nil)

			_, _ = image.NewHeavyStemcellCreator(config).
				Create(&imageServiceClient, properties.CreateStemcell{}, "root/image/path")

			imageID, imageFilePath := imageServiceClient.UploadImageArgsForCall(0)
			Expect(imageID).To(Equal("1234"))
			Expect(imageFilePath).To(Equal("root/image/path"))
		})
	})
})
