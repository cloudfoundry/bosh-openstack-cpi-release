package apiv1

import (
	bosherr "github.com/cloudfoundry/bosh-utils/errors"
)

type ActionFactory struct {
	cpiFactory CPIFactory
}

type Action interface{}

func NewActionFactory(cpiFactory CPIFactory) ActionFactory {
	return ActionFactory{cpiFactory}
}

func (f ActionFactory) Create(method string, apiVersion int, context CallContext) (interface{}, error) {
	const maxAPIVersion = 2

	if apiVersion > maxAPIVersion {
		return nil, bosherr.Errorf("CPI API version requested is '%d', max supported is '%d'", apiVersion, maxAPIVersion)
	}

	cpi, err := f.cpiFactory.New(context)
	if err != nil {
		return nil, err
	}

	// binds concrete values to interfaces

	switch method {
	case "info":
		return func() (Info, error) {
			info, err := cpi.Info()
			info.APIVersion = maxAPIVersion
			return info, err
		}, nil

	case "create_stemcell":
		return func(imagePath string, props CloudPropsImpl) (StemcellCID, error) {
			return cpi.CreateStemcell(imagePath, props)
		}, nil

	case "delete_stemcell":
		return func(cid StemcellCID) (interface{}, error) {
			return nil, cpi.DeleteStemcell(cid)
		}, nil

	case "create_vm":
		switch apiVersion {
		case 2:
			return func(
				agentID AgentID, stemcellCID StemcellCID, props CloudPropsImpl,
				networks Networks, diskCIDs []DiskCID, env VMEnv) (VMCID, Networks, error) {

				return cpi.CreateVMV2(agentID, stemcellCID, props, networks, diskCIDs, env)
			}, nil

		default:
			return func(
				agentID AgentID, stemcellCID StemcellCID, props CloudPropsImpl,
				networks Networks, diskCIDs []DiskCID, env VMEnv) (VMCID, error) {

				return cpi.CreateVM(agentID, stemcellCID, props, networks, diskCIDs, env)
			}, nil
		}

	case "delete_vm":
		return func(cid VMCID) (interface{}, error) {
			return nil, cpi.DeleteVM(cid)
		}, nil

	case "calculate_vm_cloud_properties":
		return cpi.CalculateVMCloudProperties, nil

	case "set_vm_metadata":
		return func(cid VMCID, metadata VMMeta) (interface{}, error) {
			return nil, cpi.SetVMMetadata(cid, metadata)
		}, nil

	case "has_vm":
		return cpi.HasVM, nil

	case "reboot_vm":
		return func(cid VMCID) (string, error) {
			return "", cpi.RebootVM(cid)
		}, nil

	case "get_disks":
		return func(cid VMCID) ([]DiskCID, error) {
			diskCIDs, err := cpi.GetDisks(cid)
			if len(diskCIDs) == 0 {
				return []DiskCID{}, err
			}
			return diskCIDs, err
		}, nil

	case "create_disk":
		return func(size int, props CloudPropsImpl, vmCID *VMCID) (DiskCID, error) {
			return cpi.CreateDisk(size, props, vmCID)
		}, nil

	case "delete_disk":
		return func(cid DiskCID) (interface{}, error) {
			return nil, cpi.DeleteDisk(cid)
		}, nil

	case "attach_disk":
		switch apiVersion {
		case 2:
			return func(vmCID VMCID, diskCID DiskCID) (interface{}, error) {
				return cpi.AttachDiskV2(vmCID, diskCID)
			}, nil

		default:
			return func(vmCID VMCID, diskCID DiskCID) (interface{}, error) {
				return nil, cpi.AttachDisk(vmCID, diskCID)
			}, nil
		}

	case "detach_disk":
		return func(vmCID VMCID, diskCID DiskCID) (interface{}, error) {
			return nil, cpi.DetachDisk(vmCID, diskCID)
		}, nil

	case "has_disk":
		return cpi.HasDisk, nil

	case "resize_disk":
		return func(diskCID DiskCID, size int) (interface{}, error) {
			return nil, cpi.ResizeDisk(diskCID, size)
		}, nil

	case "set_disk_metadata":
		return func(diskCID DiskCID, metadata DiskMeta) (interface{}, error) {
			return nil, cpi.SetDiskMetadata(diskCID, metadata)
		}, nil

	case "snapshot_disk":
		return cpi.SnapshotDisk, nil

	case "delete_snapshot":
		return func(snapshotCID SnapshotCID) (interface{}, error) {
			return nil, cpi.DeleteSnapshot(snapshotCID)
		}, nil

	default:
		return nil, bosherr.Errorf("Unknown method '%s'", method)
	}
}
