package methods

import (
	"errors"
	"fmt"
	"time"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/volume"
	"github.com/gophercloud/gophercloud"
)

type DeleteDiskMethod struct {
	volumeServiceBuilder volume.VolumeServiceBuilder
	cpiConfig            config.CpiConfig
	logger               utils.Logger
}

func NewDeleteDiskMethod(
	volumeServiceBuilder volume.VolumeServiceBuilder,
	cpiConfig config.CpiConfig,
	logger utils.Logger,
) DeleteDiskMethod {
	return DeleteDiskMethod{
		volumeServiceBuilder: volumeServiceBuilder,
		cpiConfig:            cpiConfig,
		logger:               logger,
	}
}

func (a DeleteDiskMethod) DeleteDisk(diskCID apiv1.DiskCID) error {
	var errDefault404 gophercloud.ErrDefault404
	openstackConfig := a.cpiConfig.Cloud.Properties.Openstack

	volumeService, err := a.volumeServiceBuilder.Build()
	if err != nil {
		return fmt.Errorf("failed to create volume service: %w", err)
	}

	volume, err := volumeService.GetVolume(diskCID.AsString())
	if err != nil {
		if errors.As(err, &errDefault404) {
			a.logger.Info("volume %s not found. Skipping.", diskCID.AsString())
			return nil
		}
		return fmt.Errorf("delete disk: %w", err)
	}

	if volume.ID != "" {
		if volume.Status != "available" {
			return fmt.Errorf("cannot delete volume %s, state is %s", diskCID.AsString(), volume.Status)
		}
		err := volumeService.DeleteVolume(volume.ID)
		if err != nil {
			return fmt.Errorf("delete disk: %w", err)
		}

		err = volumeService.WaitForVolumeToBecomeStatus(volume.ID, time.Duration(openstackConfig.StateTimeOut)*time.Second, "deleted")
		if err != nil {
			return fmt.Errorf("delete disk: %w", err)
		}
	} else {
		a.logger.Info("volume %s not found. Skipping.", diskCID.AsString())
	}
	return nil
}
