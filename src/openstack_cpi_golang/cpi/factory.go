package cpi

import (
	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/image"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/image/root_image"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/loadbalancer"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/methods"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/network"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/openstack"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/volume"
)

type Factory struct {
	cpiConfig       config.CpiConfig
	openstackConfig config.OpenstackConfig
	logger          utils.Logger
}

type CPI struct {
	methods.InfoMethod

	methods.CreateStemcellMethod
	methods.DeleteStemcellMethod

	methods.CreateVMMethod
	methods.DeleteVMMethod
	methods.CalculateVMCloudPropertiesMethod
	methods.HasVMMethod
	methods.RebootVMMethod
	methods.SetVMMetadataMethod
	methods.GetDisksMethod

	methods.CreateDiskMethod
	methods.DeleteDiskMethod
	methods.AttachDiskMethod
	methods.DetachDiskMethod
	methods.HasDiskMethod
	methods.ResizeDiskMethod
	methods.SetDiskMetadataMethod

	methods.DeleteSnapshotMethod
	methods.SnapshotDiskMethod
}

func NewFactory(
	cpiConfig config.CpiConfig,
	logger utils.Logger,
) Factory {
	return Factory{
		cpiConfig:       cpiConfig,
		openstackConfig: cpiConfig.Cloud.Properties.Openstack,
		logger:          logger,
	}
}

func (f Factory) New(ctx apiv1.CallContext) (apiv1.CPI, error) {
	openstackService := openstack.NewOpenstackService(openstack.NewOpenstackFacade(), utils.NewEnvVar())

	return CPI{
		methods.NewInfoMethod(),

		methods.NewCreateStemcellMethod(

			image.NewImageServiceBuilder(openstackService, f.cpiConfig, f.logger),
			image.NewHeavyStemcellCreator(f.openstackConfig),
			image.NewLightStemcellCreator(f.openstackConfig),
			root_image.NewRootImage(),
			f.openstackConfig,
			f.logger,
		),

		methods.NewDeleteStemcellMethod(
			image.NewImageServiceBuilder(openstackService, f.cpiConfig, f.logger),
			f.logger,
		),

		methods.NewCreateVMMethod(
			image.NewImageServiceBuilder(openstackService, f.cpiConfig, f.logger),
			network.NewNetworkServiceBuilder(openstackService, f.cpiConfig, f.logger),
			compute.NewComputeServiceBuilder(openstackService, f.cpiConfig, f.logger),
			loadbalancer.NewLoadbalancerServiceBuilder(openstackService, f.cpiConfig, f.logger),
			f.cpiConfig,
			f.logger,
		),

		methods.NewDeleteVMMethod(
			network.NewNetworkServiceBuilder(openstackService, f.cpiConfig, f.logger),
			compute.NewComputeServiceBuilder(openstackService, f.cpiConfig, f.logger),
			loadbalancer.NewLoadbalancerServiceBuilder(openstackService, f.cpiConfig, f.logger),
			f.cpiConfig,
			f.logger,
		),

		methods.NewCalculateVMCloudPropertiesMethod(
			compute.NewComputeServiceBuilder(openstackService, f.cpiConfig, f.logger),
			f.cpiConfig,
			f.logger,
		),

		methods.NewHasVMMethod(
			compute.NewComputeServiceBuilder(openstackService, f.cpiConfig, f.logger),
			f.logger,
		),

		methods.NewRebootVMMethod(
			compute.NewComputeServiceBuilder(openstackService, f.cpiConfig, f.logger),
			f.cpiConfig,
			f.logger,
		),

		methods.NewSetVMMetadataMethod(
			compute.NewComputeServiceBuilder(openstackService, f.cpiConfig, f.logger),
			f.logger,
			f.cpiConfig),
		methods.NewGetDisksMethod(
			compute.NewComputeServiceBuilder(openstackService, f.cpiConfig, f.logger),
			f.logger),
		methods.NewCreateDiskMethod(
			compute.NewComputeServiceBuilder(openstackService, f.cpiConfig, f.logger),
			volume.NewVolumeServiceBuilder(openstackService, f.cpiConfig, f.logger),
			f.cpiConfig,
			f.logger,
		),
		methods.NewDeleteDiskMethod(
			volume.NewVolumeServiceBuilder(openstackService, f.cpiConfig, f.logger),
			f.cpiConfig,
			f.logger,
		),
		methods.NewAttachDiskMethod(
			compute.NewComputeServiceBuilder(openstackService, f.cpiConfig, f.logger),
			volume.NewVolumeServiceBuilder(openstackService, f.cpiConfig, f.logger),
			f.cpiConfig,
			f.logger),
		methods.NewDetachDiskMethod(
			compute.NewComputeServiceBuilder(openstackService, f.cpiConfig, f.logger),
			volume.NewVolumeServiceBuilder(openstackService, f.cpiConfig, f.logger),
			f.cpiConfig,
			f.logger),
		methods.NewHasDiskMethod(
			volume.NewVolumeServiceBuilder(openstackService, f.cpiConfig, f.logger),
			f.logger),
		methods.NewResizeDiskMethod(
			volume.NewVolumeServiceBuilder(openstackService, f.cpiConfig, f.logger),
			f.cpiConfig,
			f.logger,
		),
		methods.NewSetDiskMetadataMethod(
			compute.NewComputeServiceBuilder(openstackService, f.cpiConfig, f.logger),
			volume.NewVolumeServiceBuilder(openstackService, f.cpiConfig, f.logger),
			f.logger),
		methods.NewDeleteSnapshotMethod(
			volume.NewVolumeServiceBuilder(openstackService, f.cpiConfig, f.logger),
			f.cpiConfig,
			f.logger),
		methods.NewSnapshotDiskMethod(
			volume.NewVolumeServiceBuilder(openstackService, f.cpiConfig, f.logger),
			f.cpiConfig,
			f.logger),
	}, nil
}
