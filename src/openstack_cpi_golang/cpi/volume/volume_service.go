package volume

import (
	"errors"
	"fmt"
	"time"

	"github.com/gophercloud/gophercloud/openstack/blockstorage/v3/snapshots"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/google/uuid"
	"github.com/gophercloud/gophercloud"
	"github.com/gophercloud/gophercloud/openstack/blockstorage/extensions/volumeactions"
	"github.com/gophercloud/gophercloud/openstack/blockstorage/v3/volumes"
)

var VolumeServicePollingInterval = 10 * time.Second

//counterfeiter:generate . VolumeService
type VolumeService interface {
	CreateVolume(
		size int,
		cloudProps properties.CreateDisk,
		az string,
	) (*volumes.Volume, error)
	WaitForVolumeToBecomeStatus(
		volumeID string,
		timeout time.Duration,
		status string,
	) error
	GetVolume(volumeID string) (*volumes.Volume, error)
	DeleteVolume(volumeId string) error
	ExtendVolumeSize(
		volumeID string,
		size int,
	) error
	SetDiskMetadata(
		volumeID string,
		metadata map[string]string,
	) error
	CreateSnapshot(
		volumeID string,
		force bool,
		name string,
		description string,
		metadata map[string]string,
	) (*snapshots.Snapshot, error)
	DeleteSnapshot(
		snapShotID string,
	) error
	UpdateMetaDataSnapshot(
		snapShotID string,
		metadata map[string]interface{},
	) (map[string]interface{}, error)
	WaitForSnapshotToBecomeStatus(
		snapShotID string,
		timeout time.Duration,
		status string,
	) error
	GetSnapshot(
		snapShotID string,
	) (*snapshots.Snapshot, error)
}

type volumeService struct {
	volumeFacade   VolumeFacade
	serviceClients utils.ServiceClients
}

func NewVolumeService(serviceClients utils.ServiceClients, volumeFacade VolumeFacade) volumeService {
	return volumeService{
		volumeFacade:   volumeFacade,
		serviceClients: serviceClients,
	}
}

func (v volumeService) CreateVolume(
	size int,
	cloudProps properties.CreateDisk,
	az string,
) (*volumes.Volume, error) {
	volumeType := cloudProps.VolumeType

	uuid, _ := uuid.NewRandom()
	name := fmt.Sprintf("volume-%s", uuid)
	createOpts := v.getVolumeCreateOpts(size, az, volumeType, name)
	volume, err := v.volumeFacade.CreateVolume(v.serviceClients.ServiceClient, createOpts)
	if err != nil {
		return nil, fmt.Errorf("failed to create volume: %w", err)
	}

	return volume, nil
}

func (v volumeService) WaitForVolumeToBecomeStatus(volumeID string, timeout time.Duration, status string) error {
	timeoutTimer := time.NewTimer(timeout)
	var errDefault404 gophercloud.ErrDefault404

	for {
		select {
		case <-timeoutTimer.C:
			return fmt.Errorf("timeout while waiting for volume to become %s", status)
		default:
			volume, err := v.GetVolume(volumeID)
			if err != nil {
				if errors.As(err, &errDefault404) && status == "deleted" {
					return nil
				}
				return err
			}

			switch volume.Status {
			case status:
				return nil
			case "error":
				return fmt.Errorf("volume became error state while waiting to become %s", status)
			}

			time.Sleep(VolumeServicePollingInterval)
		}
	}
}

func (v volumeService) GetVolume(volumeID string) (*volumes.Volume, error) {
	volume, err := v.volumeFacade.GetVolume(v.serviceClients.RetryableServiceClient, volumeID)
	if err != nil {
		return nil, fmt.Errorf("failed to retrieve volume information: %w", err)
	}
	return volume, nil
}

func (v volumeService) ExtendVolumeSize(volumeID string, size int) error {
	extendOpts := volumeactions.ExtendSizeOpts{
		NewSize: size,
	}

	err := v.volumeFacade.ExtendVolumeSize(v.serviceClients.ServiceClient, volumeID, extendOpts)
	if err != nil {
		return fmt.Errorf("failed to extend volume size: %w", err)
	}
	return nil
}

func (v volumeService) SetDiskMetadata(volumeID string, metadata map[string]string) error {
	updateOpts := volumes.UpdateOpts{
		Metadata: metadata,
	}
	err := v.volumeFacade.SetDiskMetadata(v.serviceClients.ServiceClient, volumeID, updateOpts)
	if err != nil {
		return fmt.Errorf("failed to set disk metadata: %w", err)
	}
	return nil
}

func (v volumeService) DeleteVolume(volumeID string) error {
	deleteOpts := v.getVolumeDeleteOpts()

	err := v.volumeFacade.DeleteVolume(v.serviceClients.RetryableServiceClient, volumeID, deleteOpts)
	if err != nil {
		return fmt.Errorf("failed to delete volume: %w", err)
	}
	return nil
}

func (v volumeService) CreateSnapshot(
	volumeID string,
	force bool,
	name string,
	description string,
	metadata map[string]string,
) (*snapshots.Snapshot, error) {

	snapshot, err := v.volumeFacade.CreateSnapshot(
		v.serviceClients.ServiceClient,
		snapshots.CreateOpts{
			VolumeID:    volumeID,
			Force:       force,
			Name:        name,
			Description: description,
			Metadata:    metadata},
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create snapshot: %w", err)
	}

	return snapshot, nil
}

func (v volumeService) DeleteSnapshot(snapShotID string) error {
	err := v.volumeFacade.DeleteSnapshot(v.serviceClients.ServiceClient, snapShotID)
	if err != nil {
		return fmt.Errorf("failed to delete snapshot: %w", err)
	}
	return nil
}

func (v volumeService) UpdateMetaDataSnapshot(
	snapShotID string,
	metadata map[string]interface{},
) (map[string]interface{}, error) {

	metaData, err := v.volumeFacade.UpdateMetaDataSnapShot(
		v.serviceClients.ServiceClient,
		snapShotID,
		snapshots.UpdateMetadataOpts{
			Metadata: metadata},
	)
	if err != nil {
		return nil, fmt.Errorf("failed to update metadata snapshot: %w", err)
	}

	return metaData, nil
}

func (v volumeService) GetSnapshot(snapShotID string) (*snapshots.Snapshot, error) {
	snapshot, err := v.volumeFacade.GetSnapshot(v.serviceClients.RetryableServiceClient, snapShotID)
	if err != nil {
		return nil, fmt.Errorf("failed to retrieve snapshot information: %w", err)
	}
	return snapshot, nil
}

func (v volumeService) WaitForSnapshotToBecomeStatus(snapShotID string, timeout time.Duration, status string) error {
	timeoutTimer := time.NewTimer(timeout)
	var errDefault404 gophercloud.ErrDefault404

	for {
		select {
		case <-timeoutTimer.C:
			return fmt.Errorf("timeout while waiting for snapshot to become %s", status)
		default:
			snapshot, err := v.GetSnapshot(snapShotID)
			if err != nil {
				if errors.As(err, &errDefault404) && status == "deleted" {
					return nil
				}
				return err
			}

			switch snapshot.Status {
			case status:
				return nil
			case "error":
				return fmt.Errorf("snapshot became error state while waiting to become %s", status)
			case "failed":
				return fmt.Errorf("snapshot became error state while waiting to become %s", status)
			case "killed":
				return fmt.Errorf("snapshot became error state while waiting to become %s", status)
			}

			time.Sleep(VolumeServicePollingInterval)
		}
	}
}

func (v volumeService) getVolumeCreateOpts(size int, availabilityZone string, volumeType string, name string) volumes.CreateOptsBuilder {
	createOpts := volumes.CreateOpts{
		Size:             size,
		AvailabilityZone: availabilityZone,
		VolumeType:       volumeType,
		Name:             name,
	}
	return createOpts
}

func (v volumeService) getVolumeDeleteOpts() volumes.DeleteOptsBuilder {
	deleteOpts := volumes.DeleteOpts{}
	return deleteOpts
}
