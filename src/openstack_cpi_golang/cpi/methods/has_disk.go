package methods

import (
	"errors"
	"fmt"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/volume"
	"github.com/gophercloud/gophercloud"
)

type HasDiskMethod struct {
	volumeServiceBuilder volume.VolumeServiceBuilder
	logger               utils.Logger
}

func NewHasDiskMethod(
	volumeServiceBuilder volume.VolumeServiceBuilder,
	logger utils.Logger,
) HasDiskMethod {
	return HasDiskMethod{
		volumeServiceBuilder: volumeServiceBuilder,
		logger:               logger,
	}
}

func (a HasDiskMethod) HasDisk(cid apiv1.DiskCID) (bool, error) {
	var errDefault404 gophercloud.ErrDefault404

	a.logger.Info("has_disk", "Check the presence of disk with id %s", cid.AsString())

	volumeService, err := a.volumeServiceBuilder.Build()
	if err != nil {
		return false, fmt.Errorf("has_disk: %w", err)
	}
	volume, err := volumeService.GetVolume(cid.AsString())
	if err != nil {
		if errors.As(err, &errDefault404) {
			return false, nil
		}
		return false, fmt.Errorf("has_disk: %w", err)
	}

	if volume.ID == "" {
		return false, nil
	} else {
		return true, nil
	}
}
