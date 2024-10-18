package compute

import (
	"fmt"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/extensions/bootfromvolume"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/flavors"
)

//counterfeiter:generate . VolumeConfigurator
type VolumeConfigurator interface {
	ConfigureVolumes(
		imageID string,
		openstackConfig config.OpenstackConfig,
		cloudProperties properties.CreateVM,
		flavor flavors.Flavor,
	) ([]bootfromvolume.BlockDevice, error)
}

type volumeConfigurator struct{}

func NewVolumeConfigurator() volumeConfigurator {
	return volumeConfigurator{}
}
func (v volumeConfigurator) ConfigureVolumes(imageID string, openstackConfig config.OpenstackConfig, cloudProperties properties.CreateVM, flavor flavors.Flavor) ([]bootfromvolume.BlockDevice, error) {
	bootVolumeSize, err := v.select_boot_volume_size(flavor, cloudProperties)
	if err != nil {
		return []bootfromvolume.BlockDevice{}, fmt.Errorf("failed to get volume size: %w", err)
	}

	if !v.bootFromVolume(openstackConfig, cloudProperties) {
		return []bootfromvolume.BlockDevice{}, nil
	}

	return []bootfromvolume.BlockDevice{{
		UUID:                imageID,
		SourceType:          bootfromvolume.SourceImage,
		DestinationType:     bootfromvolume.DestinationVolume,
		VolumeSize:          bootVolumeSize,
		BootIndex:           0,
		DeleteOnTermination: true,
	}}, nil
}

func (v volumeConfigurator) bootFromVolume(openstackConfig config.OpenstackConfig, cloudProperties properties.CreateVM) bool {
	if cloudProperties.BootFromVolume == nil {
		return openstackConfig.BootFromVolume
	}

	return *cloudProperties.BootFromVolume
}

func (v volumeConfigurator) select_boot_volume_size(flavor flavors.Flavor, cloudProperties properties.CreateVM) (int, error) {
	rootDiskSize := cloudProperties.RootDisk.Size
	if rootDiskSize == 0 {
		if flavor.Disk == 0 {
			return 0, fmt.Errorf("flavor '%s' has a root disk size of 0. Either pick a different flavor or define root_disk.size in your VM cloud_properties", flavor.ID)
		}
		return flavor.Disk, nil
	}

	return rootDiskSize, nil
}
