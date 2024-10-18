package volume

import (
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/gophercloud/gophercloud"
	"github.com/gophercloud/gophercloud/openstack/blockstorage/extensions/volumeactions"
	"github.com/gophercloud/gophercloud/openstack/blockstorage/v3/snapshots"
	"github.com/gophercloud/gophercloud/openstack/blockstorage/v3/volumes"
)

//counterfeiter:generate . VolumeFacade
type VolumeFacade interface {
	CreateVolume(client utils.ServiceClient, opts volumes.CreateOptsBuilder) (*volumes.Volume, error)
	GetVolume(client utils.RetryableServiceClient, volumeID string) (*volumes.Volume, error)
	DeleteVolume(client utils.RetryableServiceClient, volumeID string, opts volumes.DeleteOptsBuilder) error
	ExtendVolumeSize(client utils.ServiceClient, volumeID string, opts volumeactions.ExtendSizeOptsBuilder) error
	SetDiskMetadata(client utils.ServiceClient, volumeID string, opts volumes.UpdateOptsBuilder) error
	CreateSnapshot(client *gophercloud.ServiceClient, opts snapshots.CreateOptsBuilder) (*snapshots.Snapshot, error)
	DeleteSnapshot(client *gophercloud.ServiceClient, snapshotID string) error
	UpdateMetaDataSnapShot(client *gophercloud.ServiceClient, snapshotID string, opts snapshots.UpdateMetadataOptsBuilder) (map[string]interface{}, error)
	GetSnapshot(client utils.RetryableServiceClient, snapshotID string) (*snapshots.Snapshot, error)
}

type volumeFacade struct{}

func (v volumeFacade) CreateVolume(client utils.ServiceClient, opts volumes.CreateOptsBuilder) (*volumes.Volume, error) {
	return volumes.Create(client, opts).Extract()
}

func (v volumeFacade) GetVolume(client utils.RetryableServiceClient, volumeID string) (*volumes.Volume, error) {
	return volumes.Get(client, volumeID).Extract()
}

func (v volumeFacade) DeleteVolume(client utils.RetryableServiceClient, volumeID string, opts volumes.DeleteOptsBuilder) error {
	err := volumes.Delete(client, volumeID, opts).ExtractErr()
	if err != nil {
		return err
	}
	return nil
}

func (v volumeFacade) ExtendVolumeSize(client utils.ServiceClient, volumeID string, opts volumeactions.ExtendSizeOptsBuilder) error {
	return volumeactions.ExtendSize(client, volumeID, opts).ExtractErr()
}

func (v volumeFacade) SetDiskMetadata(client utils.ServiceClient, volumeID string, opts volumes.UpdateOptsBuilder) error {
	_, err := volumes.Update(client, volumeID, opts).Extract()
	return err
}

func (v volumeFacade) CreateSnapshot(client *gophercloud.ServiceClient, opts snapshots.CreateOptsBuilder) (*snapshots.Snapshot, error) {
	return snapshots.Create(client, opts).Extract()
}

func (v volumeFacade) DeleteSnapshot(client *gophercloud.ServiceClient, snapshotID string) error {
	return snapshots.Delete(client, snapshotID).ExtractErr()
}

func (v volumeFacade) UpdateMetaDataSnapShot(client *gophercloud.ServiceClient, snapshotID string, opts snapshots.UpdateMetadataOptsBuilder) (map[string]interface{}, error) {
	metaDataMap, err := snapshots.UpdateMetadata(client, snapshotID, opts).ExtractMetadata()
	if err != nil {
		return nil, err
	}
	return metaDataMap, nil
}

func (v volumeFacade) GetSnapshot(client utils.RetryableServiceClient, snapshotID string) (*snapshots.Snapshot, error) {
	return snapshots.Get(client, snapshotID).Extract()
}

func NewVolumeFacade() volumeFacade {
	return volumeFacade{}
}
