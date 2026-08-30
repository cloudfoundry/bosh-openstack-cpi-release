package integration_test

import (
	"fmt"
	"net/http"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Delete Disk", func() {
	// mockVolumeStatuses returns firstStatus on the first GET and restStatus on
	// every subsequent GET, modelling the volume state transition during deletion.
	// The counter is local to each invocation, so specs stay order-independent.
	mockVolumeStatuses := func(firstStatus, restStatus string) {
		callCount := 0
		Mux.HandleFunc("/v3/volumes/volume_id", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				callCount++
				status := restStatus
				if callCount == 1 {
					status = firstStatus
				}
				w.WriteHeader(http.StatusOK)
				fmt.Fprintf(w, //nolint:errcheck
					`{"volume": {"id": "volume_id", "status": "%s"}}`, status)
			case http.MethodDelete:
				w.WriteHeader(http.StatusAccepted)
			}
		})
	}

	BeforeEach(func() {
		SetupHTTP()

		MockAuthentication()
	})

	AfterEach(func() {
		TeardownHTTP()
	})

	It("deletes a volume", func() {
		mockVolumeStatuses("available", "deleted")

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
			mockVolumeStatuses("deleted", "deleted")

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
