package methods

import (
	"fmt"
	"time"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/volume"
	boshlog "github.com/cloudfoundry/bosh-utils/logger"
)

type DeleteSnapshotMethod struct {
	volumeServiceBuilder volume.VolumeServiceBuilder
	cpiConfig            config.CpiConfig
	logger               boshlog.Logger
	logTag               string
}

func NewDeleteSnapshotMethod(
	volumeServiceBuilder volume.VolumeServiceBuilder,
	cpiConfig config.CpiConfig,
	logger boshlog.Logger) DeleteSnapshotMethod {
	return DeleteSnapshotMethod{
		volumeServiceBuilder: volumeServiceBuilder,
		cpiConfig:            cpiConfig,
		logger:               logger,
		logTag:               "delete_snapshot",
	}
}

func (s DeleteSnapshotMethod) DeleteSnapshot(cid apiv1.SnapshotCID) error {

	s.logger.Info(s.logTag, "Execute delete snapshot ID %s", cid.AsString())

	volumeService, err := s.volumeServiceBuilder.Build()
	if err != nil {
		return fmt.Errorf("failed to get volume service: %w", err)
	}

	err = volumeService.DeleteSnapshot(cid.AsString())
	if err != nil {
		return fmt.Errorf("failed to delete snapshot ID %s: %w", cid.AsString(), err)
	}

	s.logger.Info(s.logTag, "Waiting for snapshot ID %s to be deleted", cid.AsString())
	err = volumeService.WaitForSnapshotToBecomeStatus(cid.AsString(), time.Duration(s.cpiConfig.OpenStackConfig().StateTimeOut)*time.Second, "deleted")
	if err != nil {
		return fmt.Errorf("failed while waiting for snapshot ID %s to be deleted: %w", cid.AsString(), err)
	}

	return nil
}
