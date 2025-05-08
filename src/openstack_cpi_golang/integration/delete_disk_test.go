package integration_test

import (
	"fmt"
	"net/http"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Delete Disk", func() {
	var callCount = 0

	BeforeEach(func() {
		SetupHTTP()

		MockAuthentication()

		Mux.HandleFunc("/v3/volumes/volume_id", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				callCount++
				if callCount == 1 {
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, //nolint:errcheck
						`{
					"volume": {
						"id": "volume_id",
						"status": "available"
					}
					}`)
				} else {
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, //nolint:errcheck
						`{
					"volume": {
						"id": "volume_id",
						"status": "deleted"
					}
					}`)
				}
			case http.MethodDelete:
				w.WriteHeader(http.StatusAccepted)
			}
		})
	})

	AfterEach(func() {
		TeardownHTTP()
	})

	It("deletes a volume", func() {
		writeJsonParamToStdIn(`{
			"method": "delete_disk",
			"arguments": [
				"volume_id"
			],
			"api_version": 2
		}`)

		err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
		Expect(err).ShouldNot(HaveOccurred())

		stdOutWriter.Close() //nolint:errcheck
		Expect(<-outChannel).To(ContainSubstring(`"result":null,"error":null`))
	})

	Context("when the volume deletion fails", func() {
		It("fails when deleting a volume", func() {
			writeJsonParamToStdIn(`{
				"method": "delete_disk",
				"arguments": [
					"volume_id"
				],
				"api_version": 2
			}`)

			err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
			Expect(err).ShouldNot(HaveOccurred())

			stdOutWriter.Close() //nolint:errcheck
			Expect(<-outChannel).To(ContainSubstring(`cannot delete volume volume_id, state is deleted`))
		})
	})
})
