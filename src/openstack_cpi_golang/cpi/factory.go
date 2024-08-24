package cpi

import (
	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/methods"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
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
	return CPI{
		methods.NewInfoMethod(),

		methods.NewCreateStemcellMethod(),
		methods.NewDeleteStemcellMethod(),
		methods.NewCreateVMMethod(),
		methods.NewDeleteVMMethod(),
		methods.NewCalculateVMCloudPropertiesMethod(),
		methods.NewHasVMMethod(),
		methods.NewRebootVMMethod(),
		methods.NewSetVMMetadataMethod(),
		methods.NewGetDisksMethod(),
		methods.NewCreateDiskMethod(),
		methods.NewDeleteDiskMethod(),
		methods.NewAttachDiskMethod(),
		methods.NewDetachDiskMethod(),
		methods.NewHasDiskMethod(),
		methods.NewResizeDiskMethod(),
		methods.NewSetDiskMetadataMethod(),
		methods.NewDeleteSnapshotMethod(),
		methods.NewSnapshotDiskMethod(),
	}, nil
}
