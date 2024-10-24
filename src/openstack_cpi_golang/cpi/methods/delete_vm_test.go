package methods_test

import (
	"errors"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute/computefakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/loadbalancer/loadbalancerfakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/methods"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/network/networkfakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	"github.com/gophercloud/gophercloud/openstack/networking/v2/ports"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("DeleteVMMethod", func() {

	var computeServiceBuilder computefakes.FakeComputeServiceBuilder
	var networkServiceBuilder networkfakes.FakeNetworkServiceBuilder
	var loadbalancerServiceBuilder loadbalancerfakes.FakeLoadbalancerServiceBuilder
	var computeService computefakes.FakeComputeService
	var networkService networkfakes.FakeNetworkService
	var loadbalancerService loadbalancerfakes.FakeLoadbalancerService
	var logger utilsfakes.FakeLogger

	Context("DELETEVMV", func() {

		BeforeEach(func() {
			computeServiceBuilder = computefakes.FakeComputeServiceBuilder{}
			networkServiceBuilder = networkfakes.FakeNetworkServiceBuilder{}
			loadbalancerServiceBuilder = loadbalancerfakes.FakeLoadbalancerServiceBuilder{}

			computeService = computefakes.FakeComputeService{}
			networkService = networkfakes.FakeNetworkService{}
			loadbalancerService = loadbalancerfakes.FakeLoadbalancerService{}

			computeServiceBuilder.BuildReturns(&computeService, nil)
			networkServiceBuilder.BuildReturns(&networkService, nil)
			loadbalancerServiceBuilder.BuildReturns(&loadbalancerService, nil)

			computeService.DeleteServerReturns(nil)
			computeService.GetMetadataReturns(map[string]string{"tag1": "tag1Value", "lbaas_pool_1": "poolID/memberID"}, nil)
			networkService.GetPortsReturns([]ports.Port{{ID: "test"}}, nil)
			networkService.DeletePortsReturns(nil)
			loadbalancerService.DeletePoolMemberReturns(nil)

			logger = utilsfakes.FakeLogger{}
		})

		It("creates the compute service", func() {
			_ = methods.NewDeleteVMMethod(
				&networkServiceBuilder,
				&computeServiceBuilder,
				&loadbalancerServiceBuilder,
				config.CpiConfig{},
				&logger,
			).DeleteVM(
				apiv1.NewVMCID("vm-id"),
			)

			Expect(computeServiceBuilder.BuildCallCount()).To(Equal(1))
		})

		It("returns an error if the compute service cannot be retrieved", func() {
			computeServiceBuilder.BuildReturns(nil, errors.New("boom"))

			err := methods.NewDeleteVMMethod(
				&networkServiceBuilder,
				&computeServiceBuilder,
				&loadbalancerServiceBuilder,
				config.CpiConfig{},
				&logger,
			).DeleteVM(
				apiv1.NewVMCID("vm-id"),
			)

			Expect(err.Error()).To(Equal("delete_vm: boom"))
		})

		It("creates the network service", func() {
			_ = methods.NewDeleteVMMethod(
				&networkServiceBuilder,
				&computeServiceBuilder,
				&loadbalancerServiceBuilder,
				config.CpiConfig{},
				&logger,
			).DeleteVM(
				apiv1.NewVMCID("vm-id"),
			)

			Expect(networkServiceBuilder.BuildCallCount()).To(Equal(1))
		})

		It("returns an error if the network service cannot be retrieved", func() {
			networkServiceBuilder.BuildReturns(nil, errors.New("boom"))

			err := methods.NewDeleteVMMethod(
				&networkServiceBuilder,
				&computeServiceBuilder,
				&loadbalancerServiceBuilder,
				config.CpiConfig{},
				&logger,
			).DeleteVM(
				apiv1.NewVMCID("vm-id"),
			)

			Expect(err.Error()).To(Equal("delete_vm: boom"))
		})

		It("get ports has been called once with the correct parameters", func() {
			err := methods.NewDeleteVMMethod(
				&networkServiceBuilder,
				&computeServiceBuilder,
				&loadbalancerServiceBuilder,
				config.CpiConfig{},
				&logger,
			).DeleteVM(
				apiv1.NewVMCID("vm-id"),
			)

			serverID, _, _ := networkService.GetPortsArgsForCall(0)
			Expect(serverID).To(Equal("vm-id"))
			Expect(err).ToNot(HaveOccurred())
		})

		It("returns an error if no ports were found", func() {
			networkService.GetPortsReturns(nil, errors.New("boom"))

			err := methods.NewDeleteVMMethod(
				&networkServiceBuilder,
				&computeServiceBuilder,
				&loadbalancerServiceBuilder,
				config.CpiConfig{},
				&logger,
			).DeleteVM(
				apiv1.NewVMCID("vm-id"),
			)

			Expect(err.Error()).To(Equal("delete_vm: boom"))

		})

		It("calls serverMetadata with correct cid", func() {
			_ = methods.NewDeleteVMMethod(
				&networkServiceBuilder,
				&computeServiceBuilder,
				&loadbalancerServiceBuilder,
				config.CpiConfig{},
				&logger,
			).DeleteVM(
				apiv1.NewVMCID("vm-id"),
			)

			serverID := computeService.GetMetadataArgsForCall(0)
			Expect(serverID).To(Equal("vm-id"))
		})

		It("returns an error if no server metadata was found", func() {
			computeService.GetMetadataReturns(nil, errors.New("boom"))

			err := methods.NewDeleteVMMethod(
				&networkServiceBuilder,
				&computeServiceBuilder,
				&loadbalancerServiceBuilder,
				config.CpiConfig{},
				&logger,
			).DeleteVM(
				apiv1.NewVMCID("vm-id"),
			)

			Expect(err.Error()).To(Equal("delete_vm: boom"))
		})

		It("creates the loadbalancer service", func() {
			err := methods.NewDeleteVMMethod(
				&networkServiceBuilder,
				&computeServiceBuilder,
				&loadbalancerServiceBuilder,
				config.CpiConfig{},
				&logger,
			).DeleteVM(
				apiv1.NewVMCID("vm-id"),
			)

			Expect(err).ToNot(HaveOccurred())
			Expect(loadbalancerServiceBuilder.BuildCallCount()).To(Equal(1))
		})

		It("returns an error if the loadbalancer service cannot be retrieved", func() {
			loadbalancerServiceBuilder.BuildReturns(nil, errors.New("boom"))

			err := methods.NewDeleteVMMethod(
				&networkServiceBuilder,
				&computeServiceBuilder,
				&loadbalancerServiceBuilder,
				config.CpiConfig{},
				&logger,
			).DeleteVM(
				apiv1.NewVMCID("vm-id"),
			)

			Expect(err.Error()).To(Equal("delete_vm: boom"))
		})

		It("does not remove pool memberships if no server tags are found", func() {
			computeService.GetMetadataReturns(map[string]string{}, nil)

			err := methods.NewDeleteVMMethod(
				&networkServiceBuilder,
				&computeServiceBuilder,
				&loadbalancerServiceBuilder,
				config.CpiConfig{},
				&logger,
			).DeleteVM(
				apiv1.NewVMCID("vm-id"),
			)

			Expect(err).ToNot(HaveOccurred())
			Expect(loadbalancerService.DeletePoolMemberCallCount()).To(Equal(0))
			Expect(computeService.DeleteServerCallCount()).To(Equal(1))
		})

		It("deletes a pool member for tags with prefix 'lbaas_pool_'", func() {
			err := methods.NewDeleteVMMethod(
				&networkServiceBuilder,
				&computeServiceBuilder,
				&loadbalancerServiceBuilder,
				config.CpiConfig{},
				&logger,
			).DeleteVM(
				apiv1.NewVMCID("vm-id"),
			)

			poolID, memberID, _ := loadbalancerService.DeletePoolMemberArgsForCall(0)

			Expect(poolID).To(Equal("poolID"))
			Expect(memberID).To(Equal("memberID"))
			Expect(err).ToNot(HaveOccurred())
			Expect(loadbalancerService.DeletePoolMemberCallCount()).To(Equal(1))
		})

		It("returns an error if deleting a pool member fails", func() {
			loadbalancerService.DeletePoolMemberReturns(errors.New("boom"))

			err := methods.NewDeleteVMMethod(
				&networkServiceBuilder,
				&computeServiceBuilder,
				&loadbalancerServiceBuilder,
				config.CpiConfig{},
				&logger,
			).DeleteVM(
				apiv1.NewVMCID("vm-id"),
			)

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("delete_vm: boom"))
		})

		It("deletes a server", func() {
			err := methods.NewDeleteVMMethod(
				&networkServiceBuilder,
				&computeServiceBuilder,
				&loadbalancerServiceBuilder,
				config.CpiConfig{},
				&logger,
			).DeleteVM(
				apiv1.NewVMCID("vm-id"),
			)

			serverID, _ := computeService.DeleteServerArgsForCall(0)
			Expect(serverID).To(Equal("vm-id"))
			Expect(err).ToNot(HaveOccurred())
		})

		It("returns an error if the server deletion fails", func() {
			computeService.DeleteServerReturns(errors.New("boom"))

			err := methods.NewDeleteVMMethod(
				&networkServiceBuilder,
				&computeServiceBuilder,
				&loadbalancerServiceBuilder,
				config.CpiConfig{},
				&logger,
			).DeleteVM(
				apiv1.NewVMCID("vm-id"),
			)

			Expect(err.Error()).To(Equal("delete_vm: boom"))
		})

		It("delete ports has been called once with the correct parameters", func() {
			err := methods.NewDeleteVMMethod(
				&networkServiceBuilder,
				&computeServiceBuilder,
				&loadbalancerServiceBuilder,
				config.CpiConfig{},
				&logger,
			).DeleteVM(
				apiv1.NewVMCID("vm-id"),
			)

			exp := []ports.Port{{ID: "test"}}
			ports := networkService.DeletePortsArgsForCall(0)
			Expect(ports).To(Equal(exp))
			Expect(err).ToNot(HaveOccurred())
		})

		It("returns an error if deleting ports fails", func() {
			networkService.DeletePortsReturns(errors.New("boom"))

			err := methods.NewDeleteVMMethod(
				&networkServiceBuilder,
				&computeServiceBuilder,
				&loadbalancerServiceBuilder,
				config.CpiConfig{},
				&logger,
			).DeleteVM(
				apiv1.NewVMCID("vm-id"),
			)

			Expect(err.Error()).To(Equal("delete_vm: boom"))

		})

	})
})
