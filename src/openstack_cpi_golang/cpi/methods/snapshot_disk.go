package methods

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/volume"
	"github.com/google/uuid"
)

type SnapshotDiskMethod struct {
	volumeServiceBuilder volume.VolumeServiceBuilder
	cpiConfig            config.CpiConfig
	logger               utils.Logger
}

func NewSnapshotDiskMethod(
	volumeServiceBuilder volume.VolumeServiceBuilder,
	cpiConfig config.CpiConfig,
	logger utils.Logger) SnapshotDiskMethod {
	return SnapshotDiskMethod{
		volumeServiceBuilder: volumeServiceBuilder,
		cpiConfig:            cpiConfig,
		logger:               logger,
	}
}

func (s SnapshotDiskMethod) SnapshotDisk(cid apiv1.DiskCID, meta apiv1.DiskMeta) (apiv1.SnapshotCID, error) {

	s.logger.Info("snapshot_disk", fmt.Sprintf("Execute snapshot for disk ID %s", cid.AsString()))

	volumeService, err := s.volumeServiceBuilder.Build()
	if err != nil {
		return apiv1.SnapshotCID{},
			fmt.Errorf("snapShotDisk: Failed to get volume service: %w", err)
	}
	currentVolume, err := volumeService.GetVolume(cid.AsString())
	if err != nil {
		return apiv1.SnapshotCID{},
			fmt.Errorf("snapShotDisk: Failed to get volume ID %s: %w", cid.AsString(), err)
	}
	var devices []string
	devices = make([]string, 0)
	for _, attachment := range currentVolume.Attachments {
		if attachment.Device != "" {
			devices = append(devices, attachment.Device)
		}
	}
	stringKeyMap, err := metaDataToMap(meta)
	if err != nil {
		return apiv1.SnapshotCID{}, fmt.Errorf("snapShotDisk: Failed to convert disk metadata: %w", err)
	}
	s.logger.Debug("snapshot_disk", fmt.Sprintf("Provided disk metadata: %v", stringKeyMap))

	description := []interface{}{
		getMapValueOrDefault(stringKeyMap, "deployment", "deployment-not-set"),
		getMapValueOrDefault(stringKeyMap, "job", "job-not-set"),
		getMapValueOrDefault(stringKeyMap, "index", "index-not-set"),
	}
	if len(devices) > 0 {
		parts := strings.Split(devices[0], "/")
		description = append(description, parts[len(parts)-1])
	}
	randomUUID, err := uuid.NewRandom()
	if err != nil {
		return apiv1.SnapshotCID{}, fmt.Errorf("snapShotDisk: Failed to create random UUID for snapshot name: %w", err)
	}
	snapshotName := "snapshot-" + randomUUID.String()
	var descriptionParts []string
	for _, value := range description {
		descriptionParts = append(descriptionParts, fmt.Sprintf("%v", value))
	}
	snapshotDescription := strings.Join(descriptionParts, "/")

	s.logger.Info("snapShotDisk", fmt.Sprintf("Creating new snapshot %s for volume %s", snapshotName, cid.AsString()))
	stringKeyMap["director"] = getMapValueOrDefault(stringKeyMap, "director_name", "director-not-set")
	stringKeyMap["instance_index"] = fmt.Sprintf("%v", getMapValueOrDefault(stringKeyMap, "index", "index-not-set"))
	stringKeyMap["instance_name"] = fmt.Sprintf("%v", fmt.Sprintf("%v", getMapValueOrDefault(stringKeyMap, "job", "job-not-set"))+"/"+fmt.Sprintf("%v", getMapValueOrDefault(stringKeyMap, "instance_id", "instance_id-not-set")))
	delete(stringKeyMap, "director_name")
	delete(stringKeyMap, "index")
	delete(stringKeyMap, "job")

	snapshot, err := volumeService.CreateSnapshot(
		cid.AsString(),
		true,
		snapshotName,
		snapshotDescription,
		convertMapToString(stringKeyMap),
	)
	if err != nil {
		return apiv1.SnapshotCID{}, fmt.Errorf("snapShotDisk: Failed to create snapshot %s for volume %s: %w", snapshotName, cid.AsString(), err)
	}
	s.logger.Info("snapShotDisk", fmt.Sprintf("Waiting for new snapshot %s for volume %s to become available", snapshotName, cid.AsString()))
	err = volumeService.WaitForSnapshotToBecomeStatus(snapshot.ID, time.Duration(s.cpiConfig.OpenStackConfig().StateTimeOut)*time.Second, "available")
	if err != nil {
		return apiv1.SnapshotCID{}, fmt.Errorf("snapShotDisk: Failed while waiting for creating snapshot %s for volume %s: %w", snapshotName, cid.AsString(), err)
	}
	return apiv1.NewSnapshotCID(snapshot.ID), nil
}

func getMapValueOrDefault(m map[string]interface{}, key string, defaultValue interface{}) interface{} {
	if val, ok := m[key]; ok {
		return val
	}
	return defaultValue
}

func metaDataToMap(meta apiv1.DiskMeta) (map[string]interface{}, error) {
	jsonBytes, err := meta.MarshalJSON()
	if err != nil {
		return nil, fmt.Errorf("metaDataToMap: Failed to convert apiv1.DiskMeta using MarshalJSON")
	}

	var resultMap map[string]interface{}
	err = json.Unmarshal(jsonBytes, &resultMap)
	if err != nil {
		return nil, fmt.Errorf("metaDataToMap: failed to convert apiv1.DiskMeta to map using Unmarshal")
	}
	for k, v := range resultMap {
		if v == nil || k == "" {
			delete(resultMap, k)
		}
	}
	return resultMap, nil
}

func convertMapToString(mapInterface map[string]interface{}) map[string]string {
	result := make(map[string]string)
	for key, value := range mapInterface {
		result[key] = fmt.Sprintf("%v", value)
	}
	return result
}
