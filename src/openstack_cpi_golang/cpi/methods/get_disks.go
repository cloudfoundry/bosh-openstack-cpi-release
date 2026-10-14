package methods

import (
	"fmt"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute"
	boshlog "github.com/cloudfoundry/bosh-utils/logger"
)

type GetDisksMethod struct {
	computeServiceBuilder compute.ComputeServiceBuilder
	logger                boshlog.Logger
	logTag                string
}

func NewGetDisksMethod(
	computeServiceBuilder compute.ComputeServiceBuilder,
	logger boshlog.Logger,
) GetDisksMethod {
	return GetDisksMethod{
		computeServiceBuilder: computeServiceBuilder,
		logger:                logger,
		logTag:                "get_disks",
	}
}

func (a GetDisksMethod) GetDisks(cid apiv1.VMCID) ([]apiv1.DiskCID, error) {

	a.logger.Info(a.logTag, "Execute get disks ID for VM ID %s", cid.AsString())

	computeService, err := a.computeServiceBuilder.Build()
	if err != nil {
		return nil, fmt.Errorf("failed to get compute service: %w", err)
	}

	_, err = computeService.GetServer(cid.AsString())
	if err != nil {
		return nil, fmt.Errorf("failed to get VM %s: %w", cid.AsString(), err)
	}

	attachmentList, err := computeService.ListVolumeAttachments(cid.AsString())
	if err != nil {
		return nil, fmt.Errorf("failed to get volume attachments for VM ID %s: %w", cid.AsString(), err)
	}
	if len(attachmentList) == 0 {
		a.logger.Debug(a.logTag, "No disks attached to VM %s", cid.AsString())
		return []apiv1.DiskCID{}, nil
	}

	disks := make([]apiv1.DiskCID, len(attachmentList))
	for idx, attachment := range attachmentList {
		disks[idx] = apiv1.NewDiskCID(attachment.VolumeID)
	}
	a.logger.Info(a.logTag, "Found %d disk(s) attached to VM %s", len(disks), cid.AsString())
	for idx, disk := range disks {
		a.logger.Debug(a.logTag, "%d: Disk ID: %s", idx, disk.AsString())
	}
	return disks, nil
}
