package methods

import (
	"fmt"
	"strings"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/loadbalancer"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/network"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
)

type DeleteVMMethod struct {
	networkServiceBuilder      network.NetworkServiceBuilder
	computeServiceBuilder      compute.ComputeServiceBuilder
	loadbalancerServiceBuilder loadbalancer.LoadbalancerServiceBuilder
	cpiConfig                  config.CpiConfig
	logger                     utils.Logger
}

func NewDeleteVMMethod(
	networkServiceBuilder network.NetworkServiceBuilder,
	computeServiceBuilder compute.ComputeServiceBuilder,
	loadbalancerServiceBuilder loadbalancer.LoadbalancerServiceBuilder,
	config config.CpiConfig,
	logger utils.Logger,
) DeleteVMMethod {
	return DeleteVMMethod{
		networkServiceBuilder:      networkServiceBuilder,
		computeServiceBuilder:      computeServiceBuilder,
		loadbalancerServiceBuilder: loadbalancerServiceBuilder,
		cpiConfig:                  config,
		logger:                     logger,
	}
}

func (a DeleteVMMethod) DeleteVM(cid apiv1.VMCID) error {
	computeService, err := a.computeServiceBuilder.Build()
	if err != nil {
		return fmt.Errorf("delete_vm: %w", err)
	}

	networkService, err := a.networkServiceBuilder.Build()
	if err != nil {
		return fmt.Errorf("delete_vm: %w", err)
	}

	// Get ports before deleting the server so that it is still assigned to the server
	ports, err := networkService.GetPorts(cid.AsString(), properties.Network{}, true)
	if err != nil {
		return fmt.Errorf("delete_vm: %w", err)
	}

	serverMetadata, err := computeService.GetMetadata(cid.AsString())
	if err != nil {
		return fmt.Errorf("delete_vm: %w", err)
	}

	if len(serverMetadata) > 0 {
		loadbalancerService, err := a.loadbalancerServiceBuilder.Build()
		if err != nil {
			return fmt.Errorf("delete_vm: %w", err)
		}

		for key, value := range serverMetadata {
			if strings.HasPrefix(key, "lbaas_pool_") {
				parts := strings.Split(value, "/")
				err = loadbalancerService.DeletePoolMember(parts[0], parts[1], a.cpiConfig.Cloud.Properties.Openstack.StateTimeOut)
				if err != nil {
					return fmt.Errorf("delete_vm: %w", err)
				}
			}
		}
	}

	err = computeService.DeleteServer(cid.AsString(), a.cpiConfig)
	if err != nil {
		return fmt.Errorf("delete_vm: %w", err)
	}

	err = networkService.DeletePorts(ports)
	if err != nil {
		return fmt.Errorf("delete_vm: %w", err)
	}

	return nil
}
