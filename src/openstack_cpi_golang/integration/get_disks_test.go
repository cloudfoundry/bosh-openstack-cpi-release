package integration_test

import (
	"fmt"
	"net/http"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("GetDisksMethod Integration Tests", func() {

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
		Mux.HandleFunc("/v2.1/servers/server-id-ok-no-disks", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.Header().Add("Content-Type", "application/json")
				w.WriteHeader(http.StatusOK)
				fmt.Fprint(w, //nolint:errcheck
					`{
					"server": {
						"id": "server-id-ok-no-disks",
						"status": "ACTIVE"
					}
				}`)
			default:
				w.WriteHeader(http.StatusNotImplemented)
			}
		})
		Mux.HandleFunc("/v2.1/servers/server-id-not-ok", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.WriteHeader(http.StatusNotFound)
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

		Mux.HandleFunc("/v2.1/servers/server-id-ok-no-disks/os-volume_attachments", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusOK)
				payload := `{ "volumeAttachments": []}`
				fmt.Fprint(w, payload) //nolint:errcheck
			default:
				w.WriteHeader(http.StatusNotImplemented)
			}
		})
	})

	AfterEach(func() {
		TeardownHTTP()
	})

	It("lists the volumes already attached", func() {
		writeJsonParamToStdIn(`{
			"method":"get_disks",
			"arguments": [
				"server-id-ok"
			],
			"context": {},
			"api_version": 2
		}`)
		err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
		Expect(err).ShouldNot(HaveOccurred())
		stdOutWriter.Close() //nolint:errcheck
		actual := <-outChannel
		Expect(actual).To(ContainSubstring(`"result":["volume-id-already-1","volume-id-already-2"],"error":null,"log":""`))
	})

	It("server not found", func() {
		writeJsonParamToStdIn(`{
			"method":"get_disks",
			"arguments": [
				"server-id-not-ok"
			],
			"context": {},
			"api_version": 2
		}`)
		err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
		Expect(err).ShouldNot(HaveOccurred())
		stdOutWriter.Close() //nolint:errcheck
		actual := <-outChannel
		Expect(actual).To(ContainSubstring(`"message":"get_disks: Failed to get VM server-id-not-ok: failed to retrieve server information: Resource not found`))
	})

	It("no disks attached to the server", func() {
		writeJsonParamToStdIn(`{
			"method":"get_disks",
			"arguments": [
				"server-id-ok-no-disks"
			],
			"context": {},
			"api_version": 2
		}`)
		err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
		Expect(err).ShouldNot(HaveOccurred())
		stdOutWriter.Close() //nolint:errcheck
		actual := <-outChannel
		Expect(actual).To(ContainSubstring(`"result":[],"error":null`))
	})
})
