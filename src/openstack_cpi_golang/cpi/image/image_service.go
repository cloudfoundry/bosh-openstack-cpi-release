package image

import (
	"bytes"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/gophercloud/gophercloud"
	"github.com/gophercloud/gophercloud/openstack/imageservice/v2/images"
)

//counterfeiter:generate . ImageService
type ImageService interface {
	CreateImage(
		cloudProps properties.CreateStemcell,
		config config.OpenstackConfig,
	) (string, error)

	GetImage(
		imageID string,
	) (string, error)

	UploadImage(
		imageID string,
		imageFilePath string,
	) error

	DeleteImage(
		imageID string,
	) error
}

type imageService struct {
	serviceClients utils.ServiceClients
	imagesFacade   ImageFacade
	httpClient     HttpClient
	logger         utils.Logger
}

func NewImageService(serviceClients utils.ServiceClients, imagesFacade ImageFacade, httpClient HttpClient, logger utils.Logger) imageService {
	return imageService{
		serviceClients: serviceClients,
		imagesFacade:   imagesFacade,
		httpClient:     httpClient,
		logger:         logger,
	}
}

func (c imageService) CreateImage(cloudProps properties.CreateStemcell, config config.OpenstackConfig) (string, error) {
	createOpts := images.CreateOpts{
		Name:            fmt.Sprintf("%s/%s", cloudProps.Name, cloudProps.Version),
		Visibility:      c.getImageVisibility(config.StemcellPubliclyVisible),
		DiskFormat:      cloudProps.DiskFormat,
		ContainerFormat: cloudProps.ContainerFormat,
		Properties:      c.getProperties(cloudProps),
	}

	image, err := c.imagesFacade.CreateImage(c.serviceClients.ServiceClient, createOpts)
	if err != nil {
		return "", fmt.Errorf("failed to create image: %w", err)
	}

	return image.ID, nil
}

func (c imageService) GetImage(imageID string) (string, error) {

	image, err := c.imagesFacade.GetImage(c.serviceClients.RetryableServiceClient, imageID)
	if err != nil {
		return "", fmt.Errorf("could not find the image '%s' in OpenStack: %w", imageID, err)
	}
	if image.Status != images.ImageStatusActive {
		return "", fmt.Errorf("image '%s' is not in active state, it is in state: %s", imageID, image.Status)
	}

	return image.ID, nil
}

func (c imageService) UploadImage(imageID string, imageFilePath string) error {
	imageData, err := os.ReadFile(imageFilePath)
	if err != nil {
		return fmt.Errorf("failed to read image file: %w", err)
	}

	endpoint := gophercloud.NormalizeURL(c.serviceClients.ServiceClient.Endpoint)
	imageURL := endpoint + "v2/images/" + imageID + "/file"

	req, err := c.httpClient.NewRequest("PUT", imageURL, bytes.NewReader(imageData))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Add("X-Auth-Token", c.serviceClients.ServiceClient.TokenID)
	req.Header.Set("Content-Type", "application/octet-stream")

	resp, err := c.httpClient.Do(req)
	if err != nil || resp.StatusCode != http.StatusNoContent {
		errMessage := ""
		if err != nil {
			errMessage += fmt.Sprintf("err: %s", err)
		}

		if resp.StatusCode != http.StatusNoContent {
			defer resp.Body.Close()
			bodyBytes, err := io.ReadAll(resp.Body)
			if err != nil {
				return fmt.Errorf("failed to read response body: %w", err)
			}
			resp.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))
			errMessage += fmt.Sprintf("response-status: '%s', response-body:'%s'\n", resp.Status, string(bodyBytes))
		}
		return fmt.Errorf("failed to upload stemcell image to %s, %s", imageURL, errMessage)
	}
	return nil
}

func (c imageService) DeleteImage(imageID string) error {
	err := c.imagesFacade.DeleteImage(c.serviceClients.RetryableServiceClient, imageID)
	if err != nil {
		return fmt.Errorf("could not delete the image %s, due to the following: %w", imageID, err)
	}
	return nil
}

func (c imageService) getImageVisibility(stemcellPubliclyVisible bool) *images.ImageVisibility {
	var visibility images.ImageVisibility
	if stemcellPubliclyVisible {
		visibility = images.ImageVisibilityPublic
	} else {
		visibility = images.ImageVisibilityPrivate
	}
	return &visibility
}

func (c imageService) getProperties(cloudProps properties.CreateStemcell) map[string]string {
	properties := make(map[string]string)
	properties["version"] = cloudProps.Version
	properties["os_type"] = cloudProps.OsType
	properties["os_distro"] = cloudProps.OsDistro
	properties["architecture"] = cloudProps.Architecture
	properties["auto_disk_config"] = strconv.FormatBool(cloudProps.AutoDiskConfig)
	properties["hw_vif_model"] = cloudProps.HwVifModel
	properties["hypervisor_type"] = cloudProps.Hypervisor
	properties["vmware_adaptertype"] = cloudProps.VmwareAdapterType
	properties["vmware_disktype"] = cloudProps.VmwareDiskType
	properties["vmware_linked_clone"] = cloudProps.VmwareLinkedClone
	properties["vmware_ostype"] = cloudProps.VmvareOsType

	// Delete the zero-values
	for key, value := range properties {
		if value == "" {
			delete(properties, key)
		}
	}

	return properties
}
