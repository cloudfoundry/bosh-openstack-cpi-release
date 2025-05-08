package integration_test

import (
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Testing the 'info' CPI method", func() {
	Describe("Invoking `info`", func() {
		It("receives expected response", func() {
			writeJsonParamToStdIn(`{
				"method":"info",
				"arguments":[],
				"context": {
					"director_uuid":"uuid",
					"request_id":"cpi-id",
					"vm":{"stemcell":{"api_version":3}}
				}
			}`)

			err := cpi.Execute(getDefaultConfig("http://foo.bar"), logger)
			Expect(err).ShouldNot(HaveOccurred())

			stdOutWriter.Close() //nolint:errcheck
			Expect(<-outChannel).To(Equal(`{"result":{"api_version":2,"stemcell_formats":["openstack-raw","openstack-qcow2","openstack-light"]},"error":null,"log":""}`))
		})
	})

})
