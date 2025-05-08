package image_test

import (
	"errors"
	"io"
	"net/http"
	"strings"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/image/imagefakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/image"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	"github.com/gophercloud/gophercloud"
	"github.com/gophercloud/gophercloud/openstack/imageservice/v2/images"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("ImageService", func() {
	var serviceClient gophercloud.ServiceClient
	var retryableServiceClient gophercloud.ServiceClient
	var serviceClients utils.ServiceClients
	var imagesFacade imagefakes.FakeImageFacade
	var httpClient imagefakes.FakeHttpClient
	var logger utilsfakes.FakeLogger

	BeforeEach(func() {
		providerClient := gophercloud.ProviderClient{}
		serviceClient = gophercloud.ServiceClient{ProviderClient: &providerClient}
		retryableServiceClient = gophercloud.ServiceClient{}
		serviceClients = utils.ServiceClients{ServiceClient: &serviceClient, RetryableServiceClient: &retryableServiceClient}
		imagesFacade = imagefakes.FakeImageFacade{}
		logger = utilsfakes.FakeLogger{}
	})

	Context("CreateImage", func() {
		BeforeEach(func() {

		})

		It("returns the id of the created image entity in OpenStack", func() {
			imagesFacade.CreateImageReturns(&images.Image{ID: "123-456"}, nil)

			imageID, err := image.NewImageService(serviceClients, &imagesFacade, &httpClient, &logger).
				CreateImage(properties.CreateStemcell{}, config.OpenstackConfig{})

			Expect(err).ToNot(HaveOccurred())
			Expect(imageID).To(Equal("123-456"))
		})

		It("create an image entity in OpenStack", func() {
			imagesFacade.CreateImageReturns(&images.Image{ID: "123-456"}, nil)

			cloudProps := properties.CreateStemcell{
				Name:            "the_stemcell_name",
				Version:         "the_stemcell_version",
				DiskFormat:      "the_disk_format",
				ContainerFormat: "the_container_format",
				OsType:          "the_os_type",
			}

			openstackConfig := config.OpenstackConfig{
				StemcellPubliclyVisible: true,
			}

			_, _ = image.NewImageService(serviceClients, &imagesFacade, &httpClient, &logger). //nolint:errcheck
														CreateImage(cloudProps, openstackConfig)

			public := images.ImageVisibilityPublic
			createOpts := images.CreateOpts{
				Name:            "the_stemcell_name/the_stemcell_version",
				Visibility:      &public,
				DiskFormat:      "the_disk_format",
				ContainerFormat: "the_container_format",
				Properties: map[string]string{
					"version":          "the_stemcell_version",
					"os_type":          "the_os_type",
					"auto_disk_config": "false",
				},
			}

			serviceClient, opts := imagesFacade.CreateImageArgsForCall(0)
			Expect(serviceClient).To(Equal(serviceClient))
			Expect(opts).To(Equal(createOpts))
		})

		It("returns an error if image entity creation in OpenStack fails", func() {
			imagesFacade.CreateImageReturns(&images.Image{ID: "123-456"}, errors.New("boom"))

			imageID, err := image.NewImageService(serviceClients, &imagesFacade, &httpClient, &logger).
				CreateImage(properties.CreateStemcell{}, config.OpenstackConfig{})

			Expect(err.Error()).To(Equal("failed to create image: boom"))
			Expect(imageID).To(Equal(""))
		})
	})

	Context("GetImage", func() {
		BeforeEach(func() {

		})

		It("returns the id of an existing image entity in OpenStack", func() {
			imagesFacade.GetImageReturns(&images.Image{ID: "123-456", Status: "active"}, nil)

			_, _ = image.NewImageService(serviceClients, &imagesFacade, &httpClient, &logger). //nolint:errcheck
														GetImage("123-456")

			serviceClient, imageID := imagesFacade.GetImageArgsForCall(0)
			Expect(serviceClient).To(Equal(serviceClient))
			Expect(imageID).To(Equal("123-456"))
		})

		It("get an existing image entity in OpenStack", func() {
			imagesFacade.GetImageReturns(&images.Image{ID: "123-456", Status: "active"}, nil)

			imageID, err := image.NewImageService(serviceClients, &imagesFacade, &httpClient, &logger).
				GetImage("123-456")

			Expect(err).ToNot(HaveOccurred())
			Expect(imageID).To(Equal("123-456"))
		})

		It("returns an error if the image entity cannot be found in OpenStack", func() {
			imagesFacade.GetImageReturns(&images.Image{ID: "123-456", Status: "active"}, errors.New("boom"))

			imageID, err := image.NewImageService(serviceClients, &imagesFacade, &httpClient, &logger).
				GetImage("123-456")

			Expect(err.Error()).To(Equal("could not find the image '123-456' in OpenStack: boom"))
			Expect(imageID).To(Equal(""))
		})

		It("returns an error if the image entity is not active in OpenStack", func() {
			imagesFacade.GetImageReturns(&images.Image{ID: "123-456", Status: "not-active"}, nil)

			imageID, err := image.NewImageService(serviceClients, &imagesFacade, &httpClient, &logger).
				GetImage("123-456")

			Expect(err.Error()).To(Equal("image '123-456' is not in active state, it is in state: not-active"))
			Expect(imageID).To(Equal(""))
		})

	})

	Context("UploadImage", func() {
		BeforeEach(func() {

		})

		It("succeeds without error", func() {
			serviceClient.ProviderClient.TokenID = "token" //nolint:staticcheck
			header := http.Header{}
			request := http.Request{Header: header}
			httpClient.NewRequestReturns(&request, nil)
			httpClient.DoReturns(&http.Response{StatusCode: 204}, nil)

			err := image.NewImageService(serviceClients, &imagesFacade, &httpClient, &logger).
				UploadImage("123-456", "testdata/root.img")

			Expect(err).To(BeNil())
		})

		It("uploads the image via PUT", func() {
			request := http.Request{Header: http.Header{}}
			httpClient := imagefakes.FakeHttpClient{}
			httpClient.NewRequestReturns(&request, nil)
			httpClient.DoReturns(&http.Response{StatusCode: 204}, nil)

			_ = image.NewImageService(serviceClients, &imagesFacade, &httpClient, &logger). //nolint:errcheck
													UploadImage("123-456", "testdata/root.img")

			Expect(httpClient.DoCallCount()).To(Equal(1))
		})

		It("returns an error if the PUT request cannot be created", func() {
			httpClient.NewRequestReturns(nil, errors.New("boom"))

			err := image.NewImageService(serviceClients, &imagesFacade, &httpClient, &logger).
				UploadImage("123-456", "testdata/root.img")

			Expect(err.Error()).To(Equal("failed to create request: boom"))
		})

		It("returns an error if the PUT request returns an error", func() {
			request := http.Request{Header: http.Header{}}
			httpClient.NewRequestReturns(&request, nil)
			httpClient.DoReturns(&http.Response{StatusCode: 204}, errors.New("boom"))

			err := image.NewImageService(serviceClients, &imagesFacade, &httpClient, &logger).
				UploadImage("123-456", "testdata/root.img")

			Expect(err.Error()).To(Equal("failed to upload stemcell image to /v2/images/123-456/file, err: boom"))
		})

		It("returns an error if the PUT request returns status code != 204", func() {
			request := http.Request{Header: http.Header{}}
			response := &http.Response{StatusCode: 404, Status: "not found", Body: io.NopCloser(strings.NewReader("content"))}
			httpClient.NewRequestReturns(&request, nil)
			httpClient.DoReturns(response, nil)

			err := image.NewImageService(serviceClients, &imagesFacade, &httpClient, &logger).
				UploadImage("123-456", "testdata/root.img")

			Expect(err.Error()).To(Equal("failed to upload stemcell image to /v2/images/123-456/file, response-status: 'not found', response-body:'content'\n"))
		})
	})

	Context("DeleteImage", func() {
		BeforeEach(func() {

		})

		It("deletes an existing image in OpenStack", func() {
			imagesFacade.DeleteImageReturns(nil)

			_ = image.NewImageService(serviceClients, &imagesFacade, &httpClient, &logger). //nolint:errcheck
													DeleteImage("123-456")

			serviceClient, imageID := imagesFacade.DeleteImageArgsForCall(0)
			Expect(serviceClient).To(Equal(serviceClient))
			Expect(imageID).To(Equal("123-456"))
		})

		It("delete an existing image entity in OpenStack without errors", func() {
			imagesFacade.DeleteImageReturns(nil)

			err := image.NewImageService(serviceClients, &imagesFacade, &httpClient, &logger).
				DeleteImage("123-456")

			Expect(err).ToNot(HaveOccurred())
			Expect(imagesFacade.DeleteImageCallCount()).To(Equal(1))
		})

		It("returns an error if the image entity cannot be found in OpenStack", func() {
			imagesFacade.DeleteImageReturns(errors.New("boom"))

			err := image.NewImageService(serviceClients, &imagesFacade, &httpClient, &logger).
				DeleteImage("123-456")

			Expect(err.Error()).To(Equal("could not delete the image 123-456, due to the following: boom"))
		})
	})
})
