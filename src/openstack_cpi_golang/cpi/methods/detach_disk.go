package methods

import (
	"fmt"
	"time"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/volume"
)

type DetachDiskMethod struct {
	computeServiceBuilder compute.ComputeServiceBuilder
	volumeServiceBuilder  volume.VolumeServiceBuilder
	cpiConfig             config.CpiConfig
	logger                utils.Logger
}

func NewDetachDiskMethod(
	computeServiceBuilder compute.ComputeServiceBuilder,
	volumeServiceBuilder volume.VolumeServiceBuilder,
	cpiConfig config.CpiConfig,
	logger utils.Logger,
) DetachDiskMethod {
	return DetachDiskMethod{
		computeServiceBuilder: computeServiceBuilder,
		volumeServiceBuilder:  volumeServiceBuilder,
		cpiConfig:             cpiConfig,
		logger:                logger,
	}
}

func (a DetachDiskMethod) DetachDisk(vmCID apiv1.VMCID, diskCID apiv1.DiskCID) error {

	openstackConfig := a.cpiConfig.Cloud.Properties.Openstack

	a.logger.Info("detach_disk", fmt.Sprintf("Execute detach disk ID %s from VM ID %s", diskCID.AsString(), vmCID.AsString()))

	computeService, err := a.computeServiceBuilder.Build()
	if err != nil {
		return fmt.Errorf("detach_disk: Failed to get compute service: %w", err)
	}
	_, err = computeService.GetServer(vmCID.AsString())
	if err != nil {
		return fmt.Errorf("detach_disk: Failed to get VM %s: %w", vmCID.AsString(), err)
	}
	attachmentList, err := computeService.ListVolumeAttachments(vmCID.AsString())
	if err != nil {
		return fmt.Errorf("detach_disk: Failed to get volume attachments for VM ID %s: %w", vmCID.AsString(), err)
	}
	attachmentFound := false
	for idx, attachment := range attachmentList {
		if idx == 0 {
			a.logger.Debug("detach_disk", fmt.Sprintf("Attachments for VM ID %s", vmCID.AsString()))
		}
		if attachment.VolumeID == diskCID.AsString() {
			attachmentFound = true
		}
		a.logger.Debug("detach_disk", fmt.Sprintf("%d: Existing attachment: device: %s, volume ID: %s", idx+1, attachment.Device, attachment.VolumeID))
	}
	if attachmentFound {
		a.logger.Debug("detach_disk", fmt.Sprintf("Detaching volume ID: %s, server: %s", diskCID.AsString(), vmCID.AsString()))
		err = computeService.DetachVolume(vmCID.AsString(), diskCID.AsString())
		if err != nil {
			return fmt.Errorf("detach_disk: Failed to detach volume %s from VM %s: %w", diskCID.AsString(), vmCID.AsString(), err)
		}
		a.logger.Debug("detach_disk", fmt.Sprintf("Detaching volume DONE: Volume ID: %s, VM ID: %s", diskCID.AsString(), vmCID.AsString()))
		a.logger.Debug("detach_disk", fmt.Sprintf("Waiting for volume ID %s to become available (time: %d secs)", diskCID.AsString(), openstackConfig.StateTimeOut))
		volumeService, err := a.volumeServiceBuilder.Build()
		if err != nil {
			return fmt.Errorf("detach_disk: Failed to get volume service (detach_disk): %w", err)
		}
		err = volumeService.WaitForVolumeToBecomeStatus(diskCID.AsString(), time.Duration(openstackConfig.StateTimeOut)*time.Second, "available")
		if err != nil {
			return fmt.Errorf("detach_disk: Timeout on waiting for volume ID %s become available (waiting: %d sec): %w",
				diskCID.AsString(), openstackConfig.StateTimeOut, err)
		}
		a.logger.Info("detach_disk", fmt.Sprintf("Successfully detached volume ID %s from VM %s (Volume status now: 'available')", diskCID.AsString(), vmCID.AsString()))
	} else {
		a.logger.Info("detach_disk", fmt.Sprintf("Volume ID %s is not attached to VM ID %s", diskCID.AsString(), vmCID.AsString()))
	}
	return nil
}
