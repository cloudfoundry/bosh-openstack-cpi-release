package methods

import (
	"errors"
	"fmt"
	"math"
	"time"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/volume"
	"github.com/gophercloud/gophercloud"
)

type CreateDiskMethod struct {
	computeServiceBuilder compute.ComputeServiceBuilder
	volumeServiceBuilder  volume.VolumeServiceBuilder
	cpiConfig             config.CpiConfig
	logger                utils.Logger
}

func NewCreateDiskMethod(
	computeServiceBuilder compute.ComputeServiceBuilder,
	volumeServiceBuilder volume.VolumeServiceBuilder,
	cpiConfig config.CpiConfig,
	logger utils.Logger,
) CreateDiskMethod {
	return CreateDiskMethod{
		computeServiceBuilder: computeServiceBuilder,
		volumeServiceBuilder:  volumeServiceBuilder,
		cpiConfig:             cpiConfig,
		logger:                logger,
	}
}

func (a CreateDiskMethod) CreateDisk(
	size int, props apiv1.DiskCloudProps, vmCID *apiv1.VMCID) (apiv1.DiskCID, error) {
	var errDefault404 gophercloud.ErrDefault404

	cloudProps := properties.CreateDisk{}
	err := props.As(&cloudProps)
	if err != nil {
		return apiv1.DiskCID{}, fmt.Errorf("failed to parse disk cloud properties: %w", err)
	}

	openstackConfig := a.cpiConfig.Cloud.Properties.Openstack

	if size < 1024 {
		return apiv1.DiskCID{}, fmt.Errorf("minimum disk size is 1 GiB")
	}
	sizeInGB := int(math.Ceil(float64(size) / 1024))
	volumeService, err := a.volumeServiceBuilder.Build()
	if err != nil {
		return apiv1.DiskCID{}, fmt.Errorf("failed to create volume service: %w", err)
	}
	computeService, err := a.computeServiceBuilder.Build()
	if err != nil {
		return apiv1.DiskCID{}, fmt.Errorf("failed to create compute service: %w", err)
	}

	server, err := computeService.GetServer(vmCID.AsString())
	if err != nil {
		if errors.As(err, &errDefault404) {
			return apiv1.DiskCID{}, nil
		}
		return apiv1.DiskCID{}, fmt.Errorf("create_disk: %w", err)
	}

	var az string
	if server.ID != "" && !openstackConfig.IgnoreServerAvailabilityZone {
		az, err = computeService.GetServerAZ(vmCID.AsString())
		if err != nil {
			return apiv1.DiskCID{}, fmt.Errorf("create_disk: %w", err)
		}
	}

	a.logger.Info("create_disk", "Creating new volume...")
	volume, err := volumeService.CreateVolume(sizeInGB, cloudProps, az)
	if err != nil {
		return apiv1.DiskCID{}, fmt.Errorf("failed to create volume: %w", err)
	}

	a.logger.Info("create_disk", fmt.Sprintf("Creating new volume %s ...", volume.ID))
	err = volumeService.WaitForVolumeToBecomeStatus(volume.ID, time.Duration(openstackConfig.StateTimeOut)*time.Second, "available")
	if err != nil {
		return apiv1.DiskCID{}, fmt.Errorf("create disk: %w", err)
	}

	return apiv1.NewDiskCID(volume.ID), nil
}
