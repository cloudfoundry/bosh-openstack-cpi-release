package integration_test

import (
	"fmt"
	"net/http"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("DELETE SNAPSHOT", func() {

	BeforeEach(func() {
		SetupHTTP()
		MockAuthentication()
	})

	AfterEach(func() {
		TeardownHTTP()
	})

	Context("Positive cases: ", func() {

		BeforeEach(func() {
			Mux.HandleFunc("/v3/snapshots/snapshot-id", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodDelete:
					w.WriteHeader(http.StatusAccepted)
				case http.MethodGet:
					w.WriteHeader(http.StatusNotFound)
				default:
					w.WriteHeader(http.StatusNotImplemented)
				}
			})
		})

		It("deletes a snapshot successfully", func() {
			writeJsonParamToStdIn(`{
				"method":"delete_snapshot",
				"arguments": ["snapshot-id"]
			}`)
			config := getDefaultConfig(Endpoint())
			err := cpi.Execute(config, logger)
			Expect(err).ShouldNot(HaveOccurred())

			_ = stdOutWriter.Close() //nolint:errcheck
			Expect(<-outChannel).To(ContainSubstring(`"result":null,"error":null`))
		})
	})

	Context("Failure in DeleteSnapshot: ", func() {

		BeforeEach(func() {
			Mux.HandleFunc("/v3/snapshots/snapshot-id", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodDelete:
					w.WriteHeader(http.StatusBadRequest) // Return 400 to simulate failure
				default:
					w.WriteHeader(http.StatusNotImplemented)
				}
			})
		})

		It("returns error if delete snapshot fails", func() {
			writeJsonParamToStdIn(`{
				"method":"delete_snapshot",
				"arguments": ["snapshot-id"]
			}`)
			config := getDefaultConfig(Endpoint())
			err := cpi.Execute(config, logger)
			Expect(err).ShouldNot(HaveOccurred())

			_ = stdOutWriter.Close() //nolint:errcheck
			Expect(<-outChannel).To(ContainSubstring(`"message":"deleteSnapshot: Failed to delete snapshot ID snapshot-id`))
		})
	})

	Context("Failure in WaitForSnapshotToBecomeStatus: ", func() {

		BeforeEach(func() {
			Mux.HandleFunc("/v3/snapshots/snapshot-id", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodDelete:
					w.WriteHeader(http.StatusAccepted)
				case http.MethodGet:
					w.WriteHeader(http.StatusOK)
					_, _ = fmt.Fprintf(w, //nolint:errcheck
						`{
						"snapshot": {
							"id": "snapshot-id",
							"status": "available"
						}
					}`)
				}
			})
		})

		It("returns error if wait for snapshot to be deleted fails", func() {
			writeJsonParamToStdIn(`{
				"method":"delete_snapshot",
				"arguments": ["snapshot-id"]
			}`)
			config := getDefaultConfig(Endpoint())
			err := cpi.Execute(config, logger)
			Expect(err).ShouldNot(HaveOccurred())

			_ = stdOutWriter.Close() //nolint:errcheck
			Expect(<-outChannel).To(ContainSubstring(`"message":"deleteSnapshot: Failed while waiting for snapshot ID snapshot-id to be deleted`))
		})
	})
})
