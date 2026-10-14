package methods

import (
	"errors"
	"fmt"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute"
	boshlog "github.com/cloudfoundry/bosh-utils/logger"
	"github.com/gophercloud/gophercloud"
)

type HasVMMethod struct {
	computeServiceBuilder compute.ComputeServiceBuilder
	logger                boshlog.Logger
}

func NewHasVMMethod(
	computeServiceBuilder compute.ComputeServiceBuilder,
	logger boshlog.Logger,
) HasVMMethod {
	return HasVMMethod{
		computeServiceBuilder: computeServiceBuilder,
		logger:                logger,
	}
}

func (a HasVMMethod) HasVM(vmCID apiv1.VMCID) (bool, error) {
	var errDefault404 gophercloud.ErrDefault404

	computeService, err := a.computeServiceBuilder.Build()
	if err != nil {
		return false, fmt.Errorf("failed to check if VM exists: %w", err)
	}

	server, err := computeService.GetServer(vmCID.AsString())
	if err != nil {
		if errors.As(err, &errDefault404) {
			return false, nil
		}
		return false, fmt.Errorf("failed to check if VM exists: %w", err)
	}

	switch server.Status {
	case "DELETED":
		return false, nil
	case "TERMINATED":
		return false, nil
	default:
		return true, nil
	}
}
