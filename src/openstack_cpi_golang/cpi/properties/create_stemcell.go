package properties

type CreateStemcell struct {
	Version           string `json:"version"`
	ImageID           string `json:"image_id"`
	Name              string `json:"name"`
	DiskFormat        string `json:"disk_format"`
	ContainerFormat   string `json:"container_format"`
	OsType            string `json:"os_type"`
	OsDistro          string `json:"os_distro"`
	Architecture      string `json:"architecture"`
	AutoDiskConfig    bool   `json:"auto_disk_config"`
	HwVifModel        string `json:"hw_vif_model"`
	Hypervisor        string `json:"hypervisor"`
	VmwareAdapterType string `json:"vmware_adaptertype"`
	VmwareDiskType    string `json:"vmware_disktype"`
	VmwareLinkedClone string `json:"vmware_linked_clone"`
	VmvareOsType      string `json:"vmware_ostype"`
}
