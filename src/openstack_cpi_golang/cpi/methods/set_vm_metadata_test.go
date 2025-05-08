package methods_test

import (
	"errors"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute/computefakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/methods"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("NewSetVMMetadataMethod", func() {

	var computeServiceBuilder *computefakes.FakeComputeServiceBuilder
	var computeService *computefakes.FakeComputeService
	var logger *utilsfakes.FakeLogger
	var cpiConfig config.CpiConfig

	Context("SetVMMetadata", func() {

		id := apiv1.NewVMCID("123-456")

		metaDataReturn := map[string]string{
			"name": "new-name",
		}

		metaDataName := apiv1.NewVMMeta(map[string]interface{}{
			"name": "new-name",
		})

		metaDataWithNil := apiv1.NewVMMeta(map[string]interface{}{
			"name": "new-name",
			"test": nil,
		})

		metaDataJobIndex := apiv1.NewVMMeta(map[string]interface{}{
			"job":   "new-job",
			"index": "1",
		})

		metaDataCompiling := apiv1.NewVMMeta(map[string]interface{}{
			"compiling": "compiling-new",
		})

		metaDataNotRelevant := apiv1.NewVMMeta(map[string]interface{}{
			"test": "test-value",
		})

		BeforeEach(func() {
			computeServiceBuilder = new(computefakes.FakeComputeServiceBuilder)
			computeService = new(computefakes.FakeComputeService)
			logger = new(utilsfakes.FakeLogger)

			computeServiceBuilder.BuildReturns(computeService, nil)

			cpiConfig = config.CpiConfig{}
			cpiConfig.Cloud.Properties.Openstack = config.OpenstackConfig{IgnoreServerAvailabilityZone: true}

			cpiConfig.Cloud.Properties.Openstack.HumanReadableVMNames = false
			cpiConfig.Cloud.Properties.Openstack.VM.Stemcell.APIVersion = 2
		})

		It("creates the compute service", func() {
			_ = methods.NewSetVMMetadataMethod( //nolint:errcheck
				computeServiceBuilder,
				logger,
				cpiConfig,
			).SetVMMetadata(
				id,
				metaDataName,
			)

			Expect(computeServiceBuilder.BuildCallCount()).To(Equal(1))
		})

		It("fails on create the compute service", func() {
			computeServiceBuilder.BuildReturns(nil, errors.New("boom"))
			err := methods.NewSetVMMetadataMethod(
				computeServiceBuilder,
				logger,
				cpiConfig,
			).SetVMMetadata(
				id,
				metaDataName,
			)

			Expect(err.Error()).To(Equal("failed to create compute service: boom"))
		})

		It("deletes nil value out imported metadata map", func() {
			_ = methods.NewSetVMMetadataMethod( //nolint:errcheck
				computeServiceBuilder,
				logger,
				cpiConfig,
			).SetVMMetadata(
				id,
				metaDataWithNil,
			)

			updateMetaExp := properties.ServerMetadata{
				"name": "new-name",
			}
			_, _, updateMetaAct := computeService.DeleteServerMetaDataArgsForCall(0)
			Expect(updateMetaAct).To(Equal(updateMetaExp))
		})

		It("fails on get MetaData", func() {
			computeService.GetMetadataReturns(nil, errors.New("boom"))
			err := methods.NewSetVMMetadataMethod(
				computeServiceBuilder,
				logger,
				cpiConfig,
			).SetVMMetadata(
				id,
				metaDataName,
			)

			Expect(err.Error()).To(Equal("failed to get Metadata: boom"))
		})

		It("get MetaData: all calls successful", func() {
			computeService.GetMetadataReturns(metaDataReturn, nil)
			err := methods.NewSetVMMetadataMethod(
				computeServiceBuilder,
				logger,
				cpiConfig,
			).SetVMMetadata(
				id,
				metaDataName,
			)

			Expect(computeService.GetMetadataCallCount()).To(Equal(2))
			Expect(err).ToNot(HaveOccurred())
		})

		It("fails on get MetaData on second call", func() {
			computeService.GetMetadataReturnsOnCall(0, metaDataReturn, nil)
			computeService.GetMetadataReturnsOnCall(1, nil, errors.New("boom"))
			err := methods.NewSetVMMetadataMethod(
				computeServiceBuilder,
				logger,
				cpiConfig,
			).SetVMMetadata(
				id,
				metaDataName,
			)

			Expect(computeService.GetMetadataCallCount()).To(Equal(2))
			Expect(err.Error()).To(Equal("failed to get Metadata: boom"))
		})

		It("fails on delete Metadata", func() {
			computeService.DeleteServerMetaDataReturns(errors.New("boom"))

			err := methods.NewSetVMMetadataMethod(
				computeServiceBuilder,
				logger,
				cpiConfig,
			).SetVMMetadata(
				id,
				metaDataName,
			)

			Expect(computeService.DeleteServerMetaDataCallCount()).To(Equal(1))
			Expect(err.Error()).To(Equal("failed to delete Metadata: boom"))
		})

		It("delete Metadata", func() {
			computeService.DeleteServerMetaDataReturns(nil)

			err := methods.NewSetVMMetadataMethod(
				computeServiceBuilder,
				logger,
				cpiConfig,
			).SetVMMetadata(
				id,
				metaDataName,
			)

			Expect(computeService.DeleteServerMetaDataCallCount()).To(Equal(1))
			Expect(err).ToNot(HaveOccurred())
		})

		It("fails on update Metadata", func() {
			computeService.UpdateServerMetadataReturns(errors.New("boom"))

			err := methods.NewSetVMMetadataMethod(
				computeServiceBuilder,
				logger,
				cpiConfig,
			).SetVMMetadata(
				id,
				metaDataName,
			)

			Expect(computeService.DeleteServerMetaDataCallCount()).To(Equal(1))
			Expect(err.Error()).To(Equal("failed to update Metadata for key 123-456: boom"))
		})

		It("applies human readable: input: server name", func() {

			computeService.GetMetadataReturns(metaDataReturn, nil)
			err := methods.NewSetVMMetadataMethod(
				computeServiceBuilder,
				logger,
				cpiConfig,
			).SetVMMetadata(
				id,
				metaDataName,
			)

			Expect(computeService.UpdateServerCallCount()).To(Equal(1))
			Expect(err).ToNot(HaveOccurred())
			arg1, arg2, arg3 := logger.InfoArgsForCall(0)
			Expect(arg1).To(Equal("set_vm_metadata_method"))
			Expect(arg2).To(Equal("Renamed VM with id '123-456"))
			Expect(arg3[0]).To(Equal("' to '"))
			Expect(arg3[1]).To(Equal("new-name"))
			Expect(arg3[2]).To(Equal("'"))
		})

		It("applies human readable: input: job + index", func() {

			computeService.GetMetadataReturns(metaDataReturn, nil)
			err := methods.NewSetVMMetadataMethod(
				computeServiceBuilder,
				logger,
				cpiConfig,
			).SetVMMetadata(
				id,
				metaDataJobIndex,
			)

			Expect(computeService.UpdateServerCallCount()).To(Equal(1))
			Expect(err).ToNot(HaveOccurred())
			arg1, arg2, arg3 := logger.InfoArgsForCall(0)
			Expect(arg1).To(Equal("set_vm_metadata_method"))
			Expect(arg2).To(Equal("Renamed VM with id '123-456"))
			Expect(arg3[0]).To(Equal("' to '"))
			Expect(arg3[1]).To(Equal("new-job/1"))
			Expect(arg3[2]).To(Equal("'"))
		})

		It("applies human readable: input: compiling", func() {

			computeService.GetMetadataReturns(metaDataReturn, nil)
			err := methods.NewSetVMMetadataMethod(
				computeServiceBuilder,
				logger,
				cpiConfig,
			).SetVMMetadata(
				id,
				metaDataCompiling,
			)

			Expect(computeService.UpdateServerCallCount()).To(Equal(1))
			Expect(err).ToNot(HaveOccurred())
			arg1, arg2, arg3 := logger.InfoArgsForCall(0)
			Expect(arg1).To(Equal("set_vm_metadata_method"))
			Expect(arg2).To(Equal("Renamed VM with id '123-456"))
			Expect(arg3[0]).To(Equal("' to '"))
			Expect(arg3[1]).To(Equal("compiling/compiling-new"))
			Expect(arg3[2]).To(Equal("'"))
		})

		It("applies human readable: input: not relevant for naming", func() {

			computeService.GetMetadataReturns(metaDataReturn, nil)
			err := methods.NewSetVMMetadataMethod(
				computeServiceBuilder,
				logger,
				cpiConfig,
			).SetVMMetadata(
				id,
				metaDataNotRelevant,
			)

			Expect(computeService.UpdateServerCallCount()).To(Equal(0))
			Expect(logger.DebugCallCount()).To(Equal(1))
			arg1, arg2, arg3 := logger.DebugArgsForCall(0)
			Expect(arg1).To(Equal("set_vm_metadata_method"))
			Expect(arg2).To(Equal("did not apply human readable name: no name, job/index and compiling provided"))
			Expect(len(arg3)).To(Equal(1))
			Expect(err).ToNot(HaveOccurred())
		})

		It("applies human readable: update server failed", func() {
			computeService.GetMetadataReturns(metaDataReturn, nil)
			computeService.UpdateServerReturns(nil, errors.New("boom"))
			err := methods.NewSetVMMetadataMethod(
				computeServiceBuilder,
				logger,
				cpiConfig,
			).SetVMMetadata(
				id,
				metaDataName,
			)
			Expect(computeService.UpdateServerCallCount()).To(Equal(1))
			Expect(err.Error()).To(Equal("failed to update human readable name on server: boom"))
		})
	})
})
