package methods

import (
	"fmt"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/flavors"
)

type CalculateVMCloudPropertiesMethod struct {
	computeServiceBuilder compute.ComputeServiceBuilder
	cpiConfig             config.CpiConfig
	logger                utils.Logger
}

func NewCalculateVMCloudPropertiesMethod(
	computeServiceBuilder compute.ComputeServiceBuilder,
	cpiConfig config.CpiConfig,
	logger utils.Logger,
) CalculateVMCloudPropertiesMethod {
	return CalculateVMCloudPropertiesMethod{
		computeServiceBuilder: computeServiceBuilder,
		cpiConfig:             cpiConfig,
		logger:                logger,
	}
}

func (a CalculateVMCloudPropertiesMethod) CalculateVMCloudProperties(requirements apiv1.VMResources) (apiv1.VMCloudProps, error) {
	computeService, err := a.computeServiceBuilder.Build()
	if err != nil {
		return nil, fmt.Errorf("calculate_vm_cloud_properties: %w", err)
	}

	bootFromVolume := a.cpiConfig.Cloud.Properties.Openstack.BootFromVolume

	matchedFlavor, err := computeService.GetMatchingFlavor(requirements, bootFromVolume)

	if err != nil {
		return nil, fmt.Errorf("calculate_vm_cloud_properties: %w", err)
	}

	return a.vmCloudProperties(requirements, matchedFlavor, bootFromVolume), nil
}

func (a CalculateVMCloudPropertiesMethod) vmCloudProperties(requirements apiv1.VMResources, flavor flavors.Flavor, bootFromVolume bool) apiv1.VMCloudProps {
	requiredBootVolumeSize := properties.OsOverheadInGb + float64(requirements.EphemeralDiskSize)/1024
	vmProperties := map[string]interface{}{
		"instance_type": flavor.Name,
	}

	if bootFromVolume && float64(flavor.Disk) < requiredBootVolumeSize {
		vmProperties["root_disk"] = map[string]interface{}{
			"size": fmt.Sprintf("%.1f", requiredBootVolumeSize),
		}
	}
	return apiv1.NewVMCloudPropsFromMap(vmProperties)
}
