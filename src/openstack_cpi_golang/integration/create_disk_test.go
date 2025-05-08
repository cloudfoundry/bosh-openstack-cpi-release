package integration_test

import (
	"fmt"
	"net/http"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Create Disk", func() {
	callCount := 0

	BeforeEach(func() {
		SetupHTTP()

		MockAuthentication()

		Mux.HandleFunc("/v3/volumes", func(w http.ResponseWriter, r *http.Request) {
			w.Header().Add("Content-Type", "application/json")

			if r.Method == "POST" {
				w.WriteHeader(http.StatusAccepted)

				fmt.Fprintf(w, //nolint:errcheck
					`{
					"volume": {
						"id": "2b955850-f177-45f7-9f49-ecb2c256d161"
					}
				}`)
			}
		})

		Mux.HandleFunc("/v2.1/servers/server-id", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.WriteHeader(http.StatusOK)
				fmt.Fprintf(w, //nolint:errcheck
					`{
					"server": {
						"id": "server-id",
        				"OS-EXT-AZ:availability_zone": "us-west"
					}
				}`)
			}
		})

		Mux.HandleFunc("/v3/volumes/2b955850-f177-45f7-9f49-ecb2c256d161", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				callCount++
				if callCount == 1 {
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, //nolint:errcheck
						`{
					"volume": {
						"id": "2b955850-f177-45f7-9f49-ecb2c256d161",
						"status": "available"        				
					}
					}`)
				} else {
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, //nolint:errcheck
						`{
					"volume": {
						"id": "2b955850-f177-45f7-9f49-ecb2c256d161",
						"status": "error"        				
					}
					}`)
				}
			}
		})
	})

	AfterEach(func() {
		TeardownHTTP()
	})

	It("creates a volume", func() {
		writeJsonParamToStdIn(`{
			"method": "create_disk",
			"arguments": [
				4096,
				{
					"type": "vmware"
				},
				"server-id"
			],
			"api_version": 2
		}`)

		err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
		Expect(err).ShouldNot(HaveOccurred())

		stdOutWriter.Close() //nolint:errcheck
		actual := <-outChannel
		Expect(actual).To(ContainSubstring(`"result":"2b955850-f177-45f7-9f49-ecb2c256d161","error":null`))
	})

	Context("when the volume creation fails", func() {
		It("fails when creating a volume", func() {
			writeJsonParamToStdIn(`{
			"method": "create_disk",
			"arguments": [
				4096,
				{
					"type": "vmware"
				},
				"server-id"
			],
			"api_version": 2
		}`)

			err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
			Expect(err).ShouldNot(HaveOccurred())

			stdOutWriter.Close() //nolint:errcheck
			actual := <-outChannel
			Expect(actual).To(ContainSubstring(`create disk: volume became error state while waiting to become available`))
		})
	})
})
