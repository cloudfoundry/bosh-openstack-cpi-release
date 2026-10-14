package methods

import (
	"fmt"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	boshlog "github.com/cloudfoundry/bosh-utils/logger"
)

type RebootVMMethod struct {
	computeServiceBuilder compute.ComputeServiceBuilder
	cpiConfig             config.CpiConfig
	logger                boshlog.Logger
	logTag                string
}

func NewRebootVMMethod(
	computeServiceBuilder compute.ComputeServiceBuilder,
	cpiConfig config.CpiConfig,
	logger boshlog.Logger,
) RebootVMMethod {
	return RebootVMMethod{
		computeServiceBuilder: computeServiceBuilder,
		cpiConfig:             cpiConfig,
		logger:                logger,
		logTag:                "reboot_vm",
	}
}

func (a RebootVMMethod) RebootVM(vmCID apiv1.VMCID) error {
	computeService, err := a.computeServiceBuilder.Build()
	if err != nil {
		return fmt.Errorf("failed to reboot VM: %w", err)
	}

	err = computeService.RebootServer(vmCID.AsString(), a.cpiConfig)
	if err != nil {
		return fmt.Errorf("failed to reboot VM: %w", err)
	}

	a.logger.Info(a.logTag, "Rebooted server with ID: '%s'", vmCID.AsString())
	return nil
}
