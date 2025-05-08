package integration_test

import (
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi"
	"github.com/gophercloud/gophercloud/openstack/blockstorage/v3/volumes"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("AttachDiskMethod Integration Tests", func() {

	var getVolumeCallCount int
	var volumeStatus string
	var attachments []volumes.Attachment

	BeforeEach(func() {
		SetupHTTP()
		MockAuthentication()
		getVolumeCallCount = 1
		Mux.HandleFunc("/v3/volumes/volume-id-ok", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusOK)
				if getVolumeCallCount == 1 {
					volumeStatus = "available"
				} else {
					volumeStatus = "in-use"
					attachments = []volumes.Attachment{
						{
							ServerID: "server-id-ok",
							Device:   "/dev/sdb",
						},
					}
				}
				responsePayload := map[string]interface{}{
					"id": "volume-id-ok",
					"volume": map[string]interface{}{
						"id":          "volume-id-ok",
						"status":      volumeStatus,
						"attachments": attachments,
					},
				}
				response, _ := json.Marshal(responsePayload) //nolint:errcheck
				fmt.Fprint(w, string(response))              //nolint:errcheck
				getVolumeCallCount++
			default:
				w.WriteHeader(http.StatusNotImplemented)
			}
		})
		Mux.HandleFunc("/v2.1/servers/server-id-ok", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusOK)
				payload := `{ 
					"server": {
						"id": "server-id-ok",
						"status": "ACTIVE"
					}
				}`
				fmt.Fprint(w, payload) //nolint:errcheck
			default:
				w.WriteHeader(http.StatusNotImplemented)
			}
		})
		Mux.HandleFunc("/v2.1/servers/server-id-ok/os-volume_attachments", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodPost:
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusOK)
				payload := `{
					"volumeAttachment": {
						"device": "/dev/sdb",
						"id": "attachment-id",
						"serverId": "server-id-ok",
						"volumeId": "volume-id-ok"
					}
				}`
				fmt.Fprint(w, payload) //nolint:errcheck
			case http.MethodGet:
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusOK)
				payload := `{ "volumeAttachments": [ {
						"device": "/dev/sdb",
						"id": "attachment-id",
						"serverId": "server-id-ok",
						"volumeId": "volume-id-ok"
				}]}`
				fmt.Fprint(w, payload) //nolint:errcheck
				//log.Printf("Mux: Payload: %s\n", payload)
			default:
				w.WriteHeader(http.StatusNotImplemented)
			}
		})
	})

	AfterEach(func() {
		TeardownHTTP()
	})

	Context("success case: AttachDisk", func() {

		It("attaches a new volume V1", func() {
			writeJsonParamToStdIn(`{
				"method":"attach_disk",
				"arguments": [
					"server-id-ok",
					"volume-id-ok"
				],
				"context": {},
				"api_version": 1
			}`)

			err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
			Expect(err).ShouldNot(HaveOccurred())
			stdOutWriter.Close() //nolint:errcheck
			actual := <-outChannel
			Expect(actual).To(ContainSubstring(`"result":null,"error":null`))
		})

		It("attaches a new volume V2", func() {
			writeJsonParamToStdIn(`{
				"method":"attach_disk",
				"arguments": [
					"server-id-ok",
					"volume-id-ok"
				],
				"context": {},
				"api_version": 2
			}`)
			err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
			Expect(err).ShouldNot(HaveOccurred())
			stdOutWriter.Close() //nolint:errcheck
			actual := <-outChannel
			Expect(actual).To(ContainSubstring(`{"result":"/dev/sdb","error":null,"log":""}`))
		})
	})
})
