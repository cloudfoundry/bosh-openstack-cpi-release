package methods

import (
	"fmt"
	"time"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/volume"
)

type DeleteSnapshotMethod struct {
	volumeServiceBuilder volume.VolumeServiceBuilder
	cpiConfig            config.CpiConfig
	logger               utils.Logger
}

func NewDeleteSnapshotMethod(
	volumeServiceBuilder volume.VolumeServiceBuilder,
	cpiConfig config.CpiConfig,
	logger utils.Logger) DeleteSnapshotMethod {
	return DeleteSnapshotMethod{
		volumeServiceBuilder: volumeServiceBuilder,
		cpiConfig:            cpiConfig,
		logger:               logger,
	}
}

func (s DeleteSnapshotMethod) DeleteSnapshot(cid apiv1.SnapshotCID) error {

	s.logger.Info("delete_snapshot", fmt.Sprintf("Execute delete snapshot ID %s", cid.AsString()))

	volumeService, err := s.volumeServiceBuilder.Build()
	if err != nil {
		return fmt.Errorf("deleteSnapshot: Failed to get volume service: %w", err)
	}

	err = volumeService.DeleteSnapshot(cid.AsString())
	if err != nil {
		return fmt.Errorf("deleteSnapshot: Failed to delete snapshot ID %s: %w", cid.AsString(), err)
	}

	s.logger.Info("delete_snapshot", fmt.Sprintf("Waiting for snapshot ID %s to be deleted", cid.AsString()))
	err = volumeService.WaitForSnapshotToBecomeStatus(cid.AsString(), time.Duration(s.cpiConfig.OpenStackConfig().StateTimeOut)*time.Second, "deleted")
	if err != nil {
		return fmt.Errorf("deleteSnapshot: Failed while waiting for snapshot ID %s to be deleted: %w", cid.AsString(), err)
	}

	return nil
}
