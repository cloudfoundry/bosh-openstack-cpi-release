package methods

import (
	"errors"
	"fmt"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/gophercloud/gophercloud"
)

type HasVMMethod struct {
	computeServiceBuilder compute.ComputeServiceBuilder
	logger                utils.Logger
}

func NewHasVMMethod(
	computeServiceBuilder compute.ComputeServiceBuilder,
	logger utils.Logger,
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
		return false, fmt.Errorf("has_vm: %w", err)
	}

	server, err := computeService.GetServer(vmCID.AsString())
	if err != nil {
		if errors.As(err, &errDefault404) {
			return false, nil
		}
		return false, fmt.Errorf("has_vm: %w", err)
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
