package methods_test

import (
	"errors"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute/computefakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/methods"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	"github.com/gophercloud/gophercloud"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/servers"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("HasVMMethod", func() {

	var computeServiceBuilder computefakes.FakeComputeServiceBuilder
	var computeService computefakes.FakeComputeService
	var logger utilsfakes.FakeLogger

	Context("HasVM", func() {
		BeforeEach(func() {
			computeServiceBuilder = computefakes.FakeComputeServiceBuilder{}
			logger = utilsfakes.FakeLogger{}

			computeServiceBuilder.BuildReturns(&computeService, nil)
			computeService.GetServerReturns(&servers.Server{ID: "123-456"}, nil)

		})

		It("creates the compute service", func() {
			_, _ = methods.NewHasVMMethod(
				&computeServiceBuilder,
				&logger,
			).HasVM(
				apiv1.NewVMCID("vm-id"),
			)

			Expect(computeServiceBuilder.BuildCallCount()).To(Equal(1))
		})

		It("returns an error and false if the compute service cannot be retrieved", func() {
			computeServiceBuilder.BuildReturns(nil, errors.New("boom"))

			exists, err := methods.NewHasVMMethod(
				&computeServiceBuilder,
				&logger,
			).HasVM(
				apiv1.NewVMCID("vm-id"),
			)

			Expect(exists).To(Equal(false))
			Expect(err.Error()).To(Equal("has_vm: boom"))
		})

		It("returns false and no error if GetServer fails with notFound", func() {
			testError := gophercloud.ErrDefault404{
				ErrUnexpectedResponseCode: gophercloud.ErrUnexpectedResponseCode{Actual: 404},
			}
			computeService.GetServerReturns(nil, testError)

			exists, err := methods.NewHasVMMethod(
				&computeServiceBuilder,
				&logger,
			).HasVM(
				apiv1.NewVMCID("vm-id"),
			)

			Expect(exists).To(Equal(false))
			Expect(err).ToNot(HaveOccurred())
		})

		It("returns false and error if GetServer fails", func() {
			computeService.GetServerReturns(nil, errors.New("boom"))

			exists, err := methods.NewHasVMMethod(
				&computeServiceBuilder,
				&logger,
			).HasVM(
				apiv1.NewVMCID("vm-id"),
			)

			Expect(exists).To(Equal(false))
			Expect(err).To(HaveOccurred())
		})

		It("returns false if no error and server.status != terminated", func() {
			computeService.GetServerReturns(&servers.Server{ID: "123-456", Status: "TERMINATED"}, nil)

			exists, err := methods.NewHasVMMethod(
				&computeServiceBuilder,
				&logger,
			).HasVM(
				apiv1.NewVMCID("vm-id"),
			)

			Expect(exists).To(Equal(false))
			Expect(err).ToNot(HaveOccurred())
		})

		It("returns false if no error and server.status != deleted", func() {
			computeService.GetServerReturns(&servers.Server{ID: "123-456", Status: "DELETED"}, nil)

			exists, err := methods.NewHasVMMethod(
				&computeServiceBuilder,
				&logger,
			).HasVM(
				apiv1.NewVMCID("vm-id"),
			)

			Expect(exists).To(Equal(false))
			Expect(err).ToNot(HaveOccurred())
		})

		It("returns true if no error and server.status != terminated or deleted", func() {
			computeService.GetServerReturns(&servers.Server{ID: "123-456", Status: "ACTIVE"}, nil)

			exists, err := methods.NewHasVMMethod(
				&computeServiceBuilder,
				&logger,
			).HasVM(
				apiv1.NewVMCID("vm-id"),
			)

			Expect(exists).To(Equal(true))
			Expect(err).ToNot(HaveOccurred())
		})
	})
})
