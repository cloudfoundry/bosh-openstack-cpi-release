package methods

import (
	"encoding/json"
	"fmt"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
)

type SetVMMetadataMethod struct {
	computeServiceBuilder compute.ComputeServiceBuilder
	logger                utils.Logger
	cpiConfig             config.CpiConfig
}

func NewSetVMMetadataMethod(
	computeServiceBuilder compute.ComputeServiceBuilder,
	logger utils.Logger,
	cpiConfig config.CpiConfig,
) SetVMMetadataMethod {
	return SetVMMetadataMethod{
		computeServiceBuilder: computeServiceBuilder,
		logger:                logger,
		cpiConfig:             cpiConfig,
	}
}

func (s SetVMMetadataMethod) SetVMMetadata(vmCID apiv1.VMCID, meta apiv1.VMMeta) error {

	computeService, err := s.computeServiceBuilder.Build()
	if err != nil {
		return fmt.Errorf("failed to create compute service: %w", err)
	}

	updateMetaDataMap, err := s.metadataToMap(meta)
	if err != nil {
		return err
	}

	oldMetaDataMap, err := computeService.GetMetadata(vmCID.AsString())
	if err != nil {
		return fmt.Errorf("failed to get Metadata: %w", err)
	}

	err = computeService.DeleteServerMetaData(vmCID.AsString(), oldMetaDataMap, updateMetaDataMap)
	if err != nil {
		return fmt.Errorf("failed to delete Metadata: %w", err)
	}

	err = computeService.UpdateServerMetadata(vmCID.AsString(), updateMetaDataMap)
	if err != nil {
		return fmt.Errorf("failed to update Metadata for key %s: %w", vmCID.AsString(), err)
	}

	metaDataMap, err := computeService.GetMetadata(vmCID.AsString())
	if err != nil {
		return fmt.Errorf("failed to get Metadata: %w", err)
	}

	if (s.cpiConfig.OpenStackConfig().HumanReadableVMNames &&
		s.cpiConfig.OpenStackConfig().VM.Stemcell.APIVersion >= 2) ||
		len(metaDataMap) > 0 {
		err = s.applyHumanReadableName(computeService, vmCID, updateMetaDataMap)
		if err != nil {
			return err
		}
	}

	return nil
}

func (s SetVMMetadataMethod) metadataToMap(meta apiv1.VMMeta) (map[string]interface{}, error) {
	jsonBytes, err := meta.MarshalJSON()
	if err != nil {
		return nil, fmt.Errorf("failed to convert apiv1.VMMeta to json: %w", err)
	}

	var intermediateMap map[string]interface{}
	err = json.Unmarshal(jsonBytes, &intermediateMap)
	if err != nil {
		return nil, fmt.Errorf("failed to convert json to map: %w", err)
	}
	for k, v := range intermediateMap {
		if v == nil || k == "" {
			delete(intermediateMap, k)
		}
	}
	return intermediateMap, nil
}

func (s SetVMMetadataMethod) applyHumanReadableName(computeService compute.ComputeService, vmCID apiv1.VMCID, metaMap map[string]interface{}) error {

	name, nameOk := metaMap["name"]
	job, jobOk := metaMap["job"]
	index, indexOk := metaMap["index"]
	compiling, compilingOk := metaMap["compiling"]

	var newServerName string
	if nameOk {
		newServerName = name.(string)
	} else if jobOk && indexOk {
		newServerName = job.(string) + "/" + index.(string)
	} else if compilingOk {
		newServerName = "compiling/" + compiling.(string)
	} else {
		s.logger.Debug("set_vm_metadata_method", "did not apply human readable name: no name, job/index and compiling provided", nil)
		return nil
	}

	_, err := computeService.UpdateServer(vmCID.AsString(), newServerName)
	if err != nil {
		return fmt.Errorf("failed to update human readable name on server: %w", err)
	}
	s.logger.Info("set_vm_metadata_method", "Renamed VM with id '"+vmCID.AsString(), "' to '", newServerName, "'")

	return nil
}
