package methods

import (
	"fmt"
	"math"
	"time"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/volume"
)

type ResizeDiskMethod struct {
	volumeServiceBuilder volume.VolumeServiceBuilder
	cpiConfig            config.CpiConfig
	logger               utils.Logger
}

func NewResizeDiskMethod(
	volumeServiceBuilder volume.VolumeServiceBuilder,
	cpiConfig config.CpiConfig,
	logger utils.Logger,
) ResizeDiskMethod {
	return ResizeDiskMethod{
		volumeServiceBuilder: volumeServiceBuilder,
		cpiConfig:            cpiConfig,
		logger:               logger,
	}
}

func (r ResizeDiskMethod) ResizeDisk(cid apiv1.DiskCID, size int) error {
	sizeInGib := mibToGib(size)

	r.logger.Info("resize_disk", fmt.Sprintf("Resizing volume %s to %d GiB (%v MiB)", cid.AsString(), sizeInGib, size))

	volumeService, err := r.volumeServiceBuilder.Build()
	if err != nil {
		return fmt.Errorf("failed to create volume service: %w", err)
	}

	volume, err := volumeService.GetVolume(cid.AsString())
	if err != nil {
		return fmt.Errorf("cannot resize volume because volume with id %s not found, error: %w", cid.AsString(), err)
	}

	switch {
	case volume.Size == sizeInGib:
		r.logger.Info("resize_disk", fmt.Sprintf("Skipping resize of disk %s because current value %d GiB is equal new value %d GiB", cid.AsString(), volume.Size, sizeInGib))
		return nil
	case volume.Size > sizeInGib:
		return fmt.Errorf("cannot resize volume to a smaller size from %d GiB to %d GiB", volume.Size, sizeInGib)
	case len(volume.Attachments) > 0:
		return fmt.Errorf("cannot resize volume %s due to attachments", cid.AsString())
	}

	err = volumeService.ExtendVolumeSize(cid.AsString(), sizeInGib)
	if err != nil {
		return fmt.Errorf("failed to resize volume %s: %w", cid.AsString(), err)
	}

	r.logger.Info("resize_disk", fmt.Sprintf("Resizing volume %s to %d GiB ...", cid.AsString(), sizeInGib))
	err = volumeService.WaitForVolumeToBecomeStatus(volume.ID, time.Duration(r.cpiConfig.OpenStackConfig().StateTimeOut)*time.Second, "available")
	if err != nil {
		return fmt.Errorf("failed while waiting on resizing volume %s: %w", cid.AsString(), err)
	}

	r.logger.Info("resize_disk", fmt.Sprintf("Resized volume %s to %d GiB", cid.AsString(), sizeInGib))

	return nil
}

func mibToGib(size int) int {
	return int(math.Ceil(float64(size) / 1024.0))
}
