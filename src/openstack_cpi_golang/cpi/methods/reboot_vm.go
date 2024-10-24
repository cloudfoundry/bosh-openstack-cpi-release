package methods

import (
	"fmt"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
)

type RebootVMMethod struct {
	computeServiceBuilder compute.ComputeServiceBuilder
	cpiConfig             config.CpiConfig
	logger                utils.Logger
}

func NewRebootVMMethod(
	computeServiceBuilder compute.ComputeServiceBuilder,
	cpiConfig config.CpiConfig,
	logger utils.Logger,
) RebootVMMethod {
	return RebootVMMethod{
		computeServiceBuilder: computeServiceBuilder,
		cpiConfig:             cpiConfig,
		logger:                logger,
	}
}

func (a RebootVMMethod) RebootVM(vmCID apiv1.VMCID) error {
	computeService, err := a.computeServiceBuilder.Build()
	if err != nil {
		return fmt.Errorf("reboot_vm: %w", err)
	}

	err = computeService.RebootServer(vmCID.AsString(), a.cpiConfig)
	if err != nil {
		return fmt.Errorf("reboot_vm: %w", err)
	}

	a.logger.Info("reboot_vm_method", fmt.Sprintf("Rebooted server with ID: '%s'", vmCID.AsString()))
	return nil
}
