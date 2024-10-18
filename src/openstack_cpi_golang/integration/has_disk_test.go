package integration_test

import (
	"fmt"
	"net/http"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Has Disk", func() {
	BeforeEach(func() {
		SetupHTTP()

		MockAuthentication()

		Mux.HandleFunc("/v3/volumes/volume_id_exists", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.WriteHeader(http.StatusOK)
				fmt.Fprintf(w, `{
					"volume": {
						"id": "volume-id"
					}
				}`)
			}
		})

		Mux.HandleFunc("/v3/volumes/volume_id_does_not_exist", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.WriteHeader(http.StatusNotFound)
			}
		})
	})

	AfterEach(func() {
		TeardownHTTP()
	})

	It("returns true if the volume exists", func() {
		writeJsonParamToStdIn(`{
				"method":"has_disk",
				"arguments": ["volume_id_exists"],
				"api_version": 2
		}`)

		err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
		Expect(err).ShouldNot(HaveOccurred())

		stdOutWriter.Close()
		Expect(<-outChannel).To(ContainSubstring(`"result":true,"error":null`))
	})

	It("returns false if the volume does not exist", func() {
		writeJsonParamToStdIn(`{
				"method":"has_disk",
				"arguments": ["volume_id_does_not_exist"],
				"api_version": 2
		}`)

		err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
		Expect(err).ShouldNot(HaveOccurred())

		stdOutWriter.Close()
		Expect(<-outChannel).To(ContainSubstring(`"result":false,"error":null`))
	})

})
