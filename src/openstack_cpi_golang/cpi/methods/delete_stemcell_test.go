package methods_test

import (
	"errors"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/image/imagefakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/methods"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("DeleteStemcellMethod", func() {

	var imageServiceBuilder imagefakes.FakeImageServiceBuilder
	var logger utilsfakes.FakeLogger
	var imageService imagefakes.FakeImageService

	Context("DeleteStemcell", func() {

		BeforeEach(func() {
			imageServiceBuilder = imagefakes.FakeImageServiceBuilder{}
			logger = utilsfakes.FakeLogger{}
		})

		It("deletes an image ID", func() {
			imageServiceBuilder.BuildReturns(&imageService, nil)
			imageService.DeleteImageReturns(nil)
			err := methods.NewDeleteStemcellMethod(
				&imageServiceBuilder,
				&logger,
			).DeleteStemcell(apiv1.NewStemcellCID("cloudID"))

			cid := imageService.DeleteImageArgsForCall(0)
			Expect(err).ToNot(HaveOccurred())
			Expect(imageService.DeleteImageCallCount()).To(Equal(1))
			Expect(cid).To(Equal("cloudID"))
		})

		It("returns an error if image cannot be deleted", func() {
			imageServiceBuilder.BuildReturns(&imageService, nil)
			imageService.DeleteImageReturns(errors.New("boom"))
			err := methods.NewDeleteStemcellMethod(
				&imageServiceBuilder,
				&logger,
			).DeleteStemcell(apiv1.NewStemcellCID("cloudID"))

			Expect(err.Error()).To(Equal("failed to delete stemcell with cid cloudID due to the following: boom"))
		})

		It("returns an error if the image service cannot be retrieved", func() {
			imageServiceBuilder.BuildReturns(nil, errors.New("boom"))
			err := methods.NewDeleteStemcellMethod(
				&imageServiceBuilder,
				&logger,
			).DeleteStemcell(apiv1.NewStemcellCID("cloudID"))

			Expect(err.Error()).To(Equal("failed to create image service: boom"))
		})
	})
})
