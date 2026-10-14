package cpi

import (
	"fmt"

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
	boshlog "github.com/cloudfoundry/bosh-utils/logger"
)

type Factory struct {
	cpiConfig       config.CpiConfig
	openstackConfig config.OpenstackConfig
	logger          boshlog.Logger
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
	logger boshlog.Logger,
) Factory {
	return Factory{
		cpiConfig:       cpiConfig,
		openstackConfig: cpiConfig.Cloud.Properties.Openstack,
		logger:          logger,
	}
}

// New builds a CPI backed by the OpenStack endpoint and credentials resolved
// for this call. It merges any OpenStack overrides present in ctx (as sent by
// a multi-CPI director) onto the job's static configuration before
// constructing the CPI's methods and service builders.
func (f Factory) New(ctx apiv1.CallContext) (apiv1.CPI, error) {
	// A multi-CPI (CPI config) director identifies which OpenStack endpoint and
	// credentials to use for this request via the call context, since a single
	// installed CPI job may need to serve several OpenStack regions/projects.
	openstackConfig, err := f.openstackConfig.MergeContext(ctx)
	if err != nil {
		return CPI{}, fmt.Errorf("failed to resolve openstack configuration from CPI call context: %w", err)
	}

	// Validate the merged configuration (whether from context or base config)
	if err := openstackConfig.Validate(); err != nil {
		return CPI{}, fmt.Errorf("invalid openstack configuration: %w", err)
	}

	cpiConfig := f.cpiConfig
	cpiConfig.Cloud.Properties.Openstack = openstackConfig

	openstackService := openstack.NewOpenstackService(openstack.NewOpenstackFacade(), utils.NewEnvVar())

	return CPI{
		methods.NewInfoMethod(),

		methods.NewCreateStemcellMethod(

			image.NewImageServiceBuilder(openstackService, cpiConfig, f.logger),
			image.NewHeavyStemcellCreator(openstackConfig),
			image.NewLightStemcellCreator(openstackConfig),
			root_image.NewRootImage(),
			openstackConfig,
			f.logger,
		),

		methods.NewDeleteStemcellMethod(
			image.NewImageServiceBuilder(openstackService, cpiConfig, f.logger),
			f.logger,
		),

		methods.NewCreateVMMethod(
			image.NewImageServiceBuilder(openstackService, cpiConfig, f.logger),
			network.NewNetworkServiceBuilder(openstackService, cpiConfig, f.logger),
			compute.NewComputeServiceBuilder(openstackService, cpiConfig, f.logger),
			loadbalancer.NewLoadbalancerServiceBuilder(openstackService, cpiConfig, f.logger),
			cpiConfig,
			f.logger,
		),

		methods.NewDeleteVMMethod(
			network.NewNetworkServiceBuilder(openstackService, cpiConfig, f.logger),
			compute.NewComputeServiceBuilder(openstackService, cpiConfig, f.logger),
			loadbalancer.NewLoadbalancerServiceBuilder(openstackService, cpiConfig, f.logger),
			cpiConfig,
			f.logger,
		),

		methods.NewCalculateVMCloudPropertiesMethod(
			compute.NewComputeServiceBuilder(openstackService, cpiConfig, f.logger),
			cpiConfig,
			f.logger,
		),

		methods.NewHasVMMethod(
			compute.NewComputeServiceBuilder(openstackService, cpiConfig, f.logger),
			f.logger,
		),

		methods.NewRebootVMMethod(
			compute.NewComputeServiceBuilder(openstackService, cpiConfig, f.logger),
			cpiConfig,
			f.logger,
		),

		methods.NewSetVMMetadataMethod(
			compute.NewComputeServiceBuilder(openstackService, cpiConfig, f.logger),
			f.logger,
			cpiConfig),
		methods.NewGetDisksMethod(
			compute.NewComputeServiceBuilder(openstackService, cpiConfig, f.logger),
			f.logger),
		methods.NewCreateDiskMethod(
			compute.NewComputeServiceBuilder(openstackService, cpiConfig, f.logger),
			volume.NewVolumeServiceBuilder(openstackService, cpiConfig, f.logger),
			cpiConfig,
			f.logger,
		),
		methods.NewDeleteDiskMethod(
			volume.NewVolumeServiceBuilder(openstackService, cpiConfig, f.logger),
			cpiConfig,
			f.logger,
		),
		methods.NewAttachDiskMethod(
			compute.NewComputeServiceBuilder(openstackService, cpiConfig, f.logger),
			volume.NewVolumeServiceBuilder(openstackService, cpiConfig, f.logger),
			cpiConfig,
			f.logger),
		methods.NewDetachDiskMethod(
			compute.NewComputeServiceBuilder(openstackService, cpiConfig, f.logger),
			volume.NewVolumeServiceBuilder(openstackService, cpiConfig, f.logger),
			cpiConfig,
			f.logger),
		methods.NewHasDiskMethod(
			volume.NewVolumeServiceBuilder(openstackService, cpiConfig, f.logger),
			f.logger),
		methods.NewResizeDiskMethod(
			volume.NewVolumeServiceBuilder(openstackService, cpiConfig, f.logger),
			cpiConfig,
			f.logger,
		),
		methods.NewSetDiskMetadataMethod(
			compute.NewComputeServiceBuilder(openstackService, cpiConfig, f.logger),
			volume.NewVolumeServiceBuilder(openstackService, cpiConfig, f.logger),
			f.logger),
		methods.NewDeleteSnapshotMethod(
			volume.NewVolumeServiceBuilder(openstackService, cpiConfig, f.logger),
			cpiConfig,
			f.logger),
		methods.NewSnapshotDiskMethod(
			volume.NewVolumeServiceBuilder(openstackService, cpiConfig, f.logger),
			cpiConfig,
			f.logger),
	}, nil
}
