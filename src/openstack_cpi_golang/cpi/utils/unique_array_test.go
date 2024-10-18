package utils_test

import (
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("UniqueArray", func() {

	It("returns an array with unique elements", func() {
		Expect(utils.UniqueArray([]string{"a", "b", "b", "a"})).To(Equal([]string{"a", "b"}))
	})

	It("can ne invoked on an empty array", func() {
		Expect(utils.UniqueArray([]string{})).To(Equal([]string{}))
	})
})
