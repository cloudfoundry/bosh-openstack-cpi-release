package integration_test

import (
	"fmt"
	"net/http"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("DetachDiskMethod Integration Tests", func() {

	detachResultSuccess := true

	BeforeEach(func() {
		SetupHTTP()
		MockAuthentication()

		Mux.HandleFunc("/v2.1/servers/server-id-ok", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.Header().Add("Content-Type", "application/json")
				w.WriteHeader(http.StatusOK)
				fmt.Fprint(w, //nolint:errcheck
					`{
					"server": {
						"id": "server-id-ok",
						"status": "ACTIVE"
					}
				}`)
			default:
				w.WriteHeader(http.StatusNotImplemented)
			}
		})
		Mux.HandleFunc("/v2.1/servers/server-id-ok/os-volume_attachments", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusOK)
				payload := `{ "volumeAttachments": [
					{
						"id": "attachment-id-1",
						"device": "/dev/sdb",
						"volumeId": "volume-id-already-1",
						"serverId": "server-id-ok",
						"tag": "tag-1",
						"delete_on_termination": false
					},
					{
						"id": "attachment-id-2",
						"device": "/dev/sdc",
						"volumeId": "volume-id-already-2",
						"serverId": "server-id-ok",
						"tag": "tag-2",
						"delete_on_termination": false
					}]}`
				fmt.Fprint(w, payload) //nolint:errcheck
			default:
				w.WriteHeader(http.StatusNotImplemented)
			}
		})
		Mux.HandleFunc("/v2.1/servers/server-id-ok/os-volume_attachments/volume-id-already-1", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodDelete:
				if detachResultSuccess == true {
					w.WriteHeader(http.StatusAccepted)
				} else {
					w.WriteHeader(http.StatusInternalServerError)
				}
			default:
				w.WriteHeader(http.StatusNotImplemented)
			}
		})
		Mux.HandleFunc("/v3/volumes/volume-id-already-1", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.Header().Add("Content-Type", "application/json")
				w.WriteHeader(http.StatusOK)
				fmt.Fprint(w, //nolint:errcheck
					`{
					"volume": {
						"id": "volume-id-already-1",
						"status": "available"
					}
					}`)
			default:
				w.WriteHeader(http.StatusNotImplemented)
			}
		})
	})

	AfterEach(func() {
		TeardownHTTP()
	})

	Context("success: DetachDisk", func() {

		It("volume already attached", func() {
			writeJsonParamToStdIn(`{
				"method":"detach_disk",
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
			Expect(actual).To(ContainSubstring(`"result":null,"error":null`))
		})

		It("volume gets detached", func() {
			writeJsonParamToStdIn(`{
				"method":"detach_disk",
				"arguments": [
					"server-id-ok",
					"volume-id-already-1"
				],
				"context": {},
				"api_version": 2
			}`)
			err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
			Expect(err).ShouldNot(HaveOccurred())
			stdOutWriter.Close() //nolint:errcheck
			actual := <-outChannel
			Expect(actual).To(ContainSubstring(`"result":null,"error":null`))
		})
	})

	Context("failure: DetachDisk", func() {

		It("volume detach failed", func() {
			detachResultSuccess = false
			writeJsonParamToStdIn(`{
				"method":"detach_disk",
				"arguments": [
					"server-id-ok",
					"volume-id-already-1"
				],
				"context": {},
				"api_version": 2
			}`)
			currentConfig := getDefaultConfig(Endpoint())
			currentConfig.Cloud.Properties.RetryConfig = config.RetryConfigMap{
				"default": config.RetryConfig{
					MaxAttempts:   0,
					SleepDuration: 0,
				},
			}
			err := cpi.Execute(currentConfig, logger)
			Expect(err).ShouldNot(HaveOccurred())
			stdOutWriter.Close() //nolint:errcheck
			actual := <-outChannel
			Expect(actual).To(ContainSubstring("Internal Server Error"))
		})

	})
})
