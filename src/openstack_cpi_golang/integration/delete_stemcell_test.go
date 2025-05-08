package integration_test

import (
	"net/http"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("DELETE STEMCELL", func() {
	BeforeEach(func() {
		SetupHTTP()

		MockAuthentication()
	})

	AfterEach(func() {
		TeardownHTTP()
	})

	It("delete the stemcell image", func() {
		Mux.HandleFunc("/v2/images/b2173dd3-7ad6-4362-baa6-a68bce3565cb", func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusAccepted)
		})

		writeJsonParamToStdIn(`{
			"method":"delete_stemcell",
			"arguments":[
				 "b2173dd3-7ad6-4362-baa6-a68bce3565cb"
			]
		  }`)

		err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
		Expect(err).ShouldNot(HaveOccurred())

		stdOutWriter.Close() //nolint:errcheck
		Expect(<-outChannel).To(ContainSubstring(`"error":null`))
	})
})
