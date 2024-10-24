package methods

import (
	"encoding/json"
	"fmt"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/volume"
)

type SetDiskMetadataMethod struct {
	computeServiceBuilder compute.ComputeServiceBuilder
	volumeServiceBuilder  volume.VolumeServiceBuilder
	logger                utils.Logger
}

func NewSetDiskMetadataMethod(
	computeServiceBuilder compute.ComputeServiceBuilder,
	volumeServiceBuilder volume.VolumeServiceBuilder,
	logger utils.Logger,
) SetDiskMetadataMethod {
	return SetDiskMetadataMethod{
		computeServiceBuilder: computeServiceBuilder,
		volumeServiceBuilder:  volumeServiceBuilder,
		logger:                logger,
	}
}

func (s SetDiskMetadataMethod) SetDiskMetadata(diskCID apiv1.DiskCID, metaData apiv1.DiskMeta) error {
	s.logger.Info("set_disk_metadata", fmt.Sprintf("Execute set disk metadata disk ID %s", diskCID.AsString()))
	volumeService, err := s.volumeServiceBuilder.Build()
	if err != nil {
		return fmt.Errorf("set_disk_metadata: Failed to get volume service: %w", err)
	}
	volumeInfo, err := volumeService.GetVolume(diskCID.AsString())
	if err != nil {
		return fmt.Errorf("set_disk_metadata: Failed to get volume ID %s: %w", diskCID.AsString(), err)
	}
	s.logger.Info("set_disk_metadata", fmt.Sprintf("Successfully got volume ID %s. Current volume metadata: %v", diskCID.AsString(), volumeInfo.Metadata))
	var metaDataStringMap = make(map[string]string)
	jsonData, err := json.Marshal(metaData)
	if err != nil {
		return fmt.Errorf("set_disk_metadata: Failed to marshal metadata for volume ID %s: %w", diskCID.AsString(), err)
	}
	err = json.Unmarshal(jsonData, &metaDataStringMap)
	if err != nil {
		return fmt.Errorf("set_disk_metadata: Failed to unmarshal metadata for volume ID %s: %w", diskCID.AsString(), err)
	}
	s.logger.Info("set_disk_metadata", fmt.Sprintf("Setting metadata for volume ID %s: %v", diskCID.AsString(), metaDataStringMap))
	err = volumeService.SetDiskMetadata(diskCID.AsString(), metaDataStringMap)
	if err != nil {
		return fmt.Errorf("set_disk_metadata: Failed to set metadata for volume ID %s: %w", diskCID.AsString(), err)
	}
	s.logger.Info("set_disk_metadata", fmt.Sprintf("Successfully set metadata for volume ID %s)", diskCID.AsString()))
	return nil
}
