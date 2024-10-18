package image

import (
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/gophercloud/gophercloud/openstack/imageservice/v2/images"
)

//counterfeiter:generate . ImageFacade
type ImageFacade interface {
	CreateImage(client utils.ServiceClient, opts images.CreateOptsBuilder) (*images.Image, error)

	GetImage(client utils.RetryableServiceClient, id string) (*images.Image, error)

	DeleteImage(client utils.RetryableServiceClient, id string) error
}

type imagesFacade struct{}

func NewImageFacade() ImageFacade {
	return imagesFacade{}
}

func (c imagesFacade) CreateImage(serviceClient utils.ServiceClient, createOpts images.CreateOptsBuilder) (*images.Image, error) {
	return images.Create(serviceClient, createOpts).Extract()
}

func (c imagesFacade) GetImage(serviceClient utils.RetryableServiceClient, id string) (*images.Image, error) {
	return images.Get(serviceClient, id).Extract()
}

func (c imagesFacade) DeleteImage(serviceClient utils.RetryableServiceClient, id string) error {
	return images.Delete(serviceClient, id).ExtractErr()
}
