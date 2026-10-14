package methods

import (
	"errors"
	"fmt"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/volume"
	boshlog "github.com/cloudfoundry/bosh-utils/logger"
	"github.com/gophercloud/gophercloud"
)

type HasDiskMethod struct {
	volumeServiceBuilder volume.VolumeServiceBuilder
	logger               boshlog.Logger
	logTag               string
}

func NewHasDiskMethod(
	volumeServiceBuilder volume.VolumeServiceBuilder,
	logger boshlog.Logger,
) HasDiskMethod {
	return HasDiskMethod{
		volumeServiceBuilder: volumeServiceBuilder,
		logger:               logger,
		logTag:               "has_disk",
	}
}

func (a HasDiskMethod) HasDisk(cid apiv1.DiskCID) (bool, error) {
	var errDefault404 gophercloud.ErrDefault404

	a.logger.Info(a.logTag, "Check the presence of disk with id %s", cid.AsString())

	volumeService, err := a.volumeServiceBuilder.Build()
	if err != nil {
		return false, fmt.Errorf("failed to check if disk exists: %w", err)
	}
	volume, err := volumeService.GetVolume(cid.AsString())
	if err != nil {
		if errors.As(err, &errDefault404) {
			return false, nil
		}
		return false, fmt.Errorf("failed to check if disk exists: %w", err)
	}

	if volume.ID == "" {
		return false, nil
	} else {
		return true, nil
	}
}
