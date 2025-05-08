package methods_test

import (
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/methods"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Info", func() {

	Context("GET", func() {
		It("returns CPI information", func() {
			subject := methods.NewInfoMethod()
			info, _ := subject.Info() //nolint:errcheck

			Expect(info.APIVersion).To(Equal(2))
			Expect(info.StemcellFormats).To(Equal([]string{"openstack-raw", "openstack-qcow2", "openstack-light"}))
		})
	})

})
