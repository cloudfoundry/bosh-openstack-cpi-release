package integration_test

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("REBOOT VM", func() {
	var getServerCount = 0

	BeforeEach(func() {
		SetupHTTP()

		Mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				_, _ = fmt.Fprintf(w, //nolint:errcheck
					`{
					"versions": {"values": [
						{"status": "stable","id": "v3.0","links": [{ "href": "%s", "rel": "self" }]},
						{"status": "stable","id": "v2.0","links": [{ "href": "%s", "rel": "self" }]}
					]}
				}`, Endpoint()+"/v3", Endpoint()+"/v2.0")
			}
		})

		Mux.HandleFunc("/v3/auth/tokens", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodPost:
				w.Header().Add("X-Subject-Token", "0123456789")
				w.WriteHeader(http.StatusCreated)

				_, _ = fmt.Fprintf(w, //nolint:errcheck
					`{
					"token": {
						"expires_at": "2013-02-02T18:30:59.000000Z",
						"catalog": [{
							"endpoints": [
								{"id": "1", "interface": "public", "region": "RegionOne", "url": "%s/v2.1"},
								{"id": "2", "interface": "admin", "region": "RegionOne", "url": "%s/v2.1"},
								{"id": "3", "interface": "internal", "region": "RegionOne", "url": "%s/v2.1"}
							],
							"type": "compute", 
							"name": "nova"
						},{
							"endpoints": [
								{"id": "1", "interface": "public", "region": "RegionOne", "url": "%s/"},
								{"id": "2", "interface": "admin", "region": "RegionOne", "url": "%s/"},
								{"id": "3", "interface": "internal", "region": "RegionOne", "url": "%s/"}
							],
							"type": "network", 
							"name": "neutron"
						},{
							"endpoints": [{"url": "%s/","interface": "public","region": "RegionOne"}],
							"type": "image",
							"name": "glance"
						},{
						   "endpoints": [
							 { "id": "1", "interface": "public",  "region": "RegionOne", "url": "%s/v2.0"},
							 { "id": "2", "interface": "admin",   "region": "RegionOne", "url": "%s/v2.0"},
							 { "id": "3", "interface": "internal","region": "RegionOne", "url": "%s/v2.0"}
						  ],
						  "type": "load-balancer",
						  "name": "octavia"
						}]
					}
				}`, Endpoint(), Endpoint(), Endpoint(), Endpoint(), Endpoint(), Endpoint(), Endpoint(), Endpoint(), Endpoint(), Endpoint())
			}
		})

		Mux.HandleFunc("/v2.1/servers/active-server-id", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.WriteHeader(http.StatusOK)
				_, _ = fmt.Fprintf(w, //nolint:errcheck
					`{
					"server": {
						"id": "active-server-id",
						"status": "ACTIVE"
					}
				}`)
			}
		})

		Mux.HandleFunc("/v2.1/servers/wrong-vm-id", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.WriteHeader(http.StatusNotFound)
				_, _ = fmt.Fprintf(w, `{}`) //nolint:errcheck
			}
		})

		Mux.HandleFunc("/v2.1/servers/error-reboot-server-id", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.WriteHeader(http.StatusOK)
				_, _ = fmt.Fprintf(w, //nolint:errcheck
					`{
					"server": {
						"id": "error-reboot-server-id",
						"status": "ACTIVE"
					}
				}`)
			}
		})

		Mux.HandleFunc("/v2.1/servers/error-server-state-id", func(w http.ResponseWriter, r *http.Request) {
			getServerCount++
			switchCase := getServerCount % 2

			w.WriteHeader(http.StatusOK)

			switch switchCase {
			case 1:
				_, _ = fmt.Fprintf(w, //nolint:errcheck
					`{
					"server": {
						"id": "error-server-state-id",
						"status": "ACTIVE"
					}
				}`)
			case 0:
				_, _ = fmt.Fprintf(w, //nolint:errcheck
					`{
					"server": {
						"id": "error-server-state-id",
						"status": "ERROR"
					}
				}`)
			}
		})

		Mux.HandleFunc("/v2.1/servers/active-server-id/action", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodPost:
				var result map[string]interface{}
				body, _ := io.ReadAll(r.Body)     //nolint:errcheck
				_ = json.Unmarshal(body, &result) //nolint:errcheck

				cpiRebootMethod := result["reboot"].(map[string]interface{})
				if cpiRebootMethod["type"].(string) == "SOFT" {
					w.WriteHeader(http.StatusAccepted)
					_, _ = fmt.Fprintf(w, `{ }`) //nolint:errcheck
				}
			}
		})

		Mux.HandleFunc("/v2.1/servers/error-reboot-server-id/action", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodPost:
				var result map[string]interface{}
				body, _ := io.ReadAll(r.Body)     //nolint:errcheck
				_ = json.Unmarshal(body, &result) //nolint:errcheck

				cpiRebootMethod := result["reboot"].(map[string]interface{})
				if cpiRebootMethod["type"].(string) == "SOFT" {
					w.WriteHeader(http.StatusNotFound)
					_, _ = fmt.Fprintf(w, `{}`) //nolint:errcheck
				}
			}
		})

		Mux.HandleFunc("/v2.1/servers/error-server-state-id/action", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodPost:
				var result map[string]interface{}
				body, _ := io.ReadAll(r.Body)     //nolint:errcheck
				_ = json.Unmarshal(body, &result) //nolint:errcheck

				cpiRebootMethod := result["reboot"].(map[string]interface{})
				if cpiRebootMethod["type"].(string) == "SOFT" {
					w.WriteHeader(http.StatusAccepted)
					_, _ = fmt.Fprintf(w, `{ }`) //nolint:errcheck
				}
			}
		})

	})

	AfterEach(func() {
		TeardownHTTP()
	})

	It("Reboots a server", func() {
		writeJsonParamToStdIn(`{
				"method":"reboot_vm",
				"arguments": ["active-server-id"],
				"api_version": 2
		}`)

		cpiConfig := getDefaultConfig(Endpoint())
		cpiConfig.Cloud.Properties.Openstack.StateTimeOut = 1

		err := cpi.Execute(cpiConfig, logger)
		Expect(err).ShouldNot(HaveOccurred())

		_ = stdOutWriter.Close() //nolint:errcheck
		Expect(<-outChannel).To(ContainSubstring(`"result":"","error":null`))
	})

	It("Fails if a server is not found", func() {
		writeJsonParamToStdIn(`{
				"method":"reboot_vm",
				"arguments": ["wrong-vm-id"],
				"api_version": 2
		}`)

		err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
		Expect(err).ShouldNot(HaveOccurred())

		_ = stdOutWriter.Close() //nolint:errcheck
		Expect(<-outChannel).To(
			ContainSubstring(`reboot_vm: failed to retrieve server information: Resource not found`),
		)
	})

	It("Fails if rebooting server raises an error", func() {
		writeJsonParamToStdIn(`{
				"method":"reboot_vm",
				"arguments": ["error-reboot-server-id"],
				"api_version": 2
		}`)

		err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
		Expect(err).ShouldNot(HaveOccurred())

		_ = stdOutWriter.Close() //nolint:errcheck
		Expect(<-outChannel).To(
			ContainSubstring(`reboot_vm: failed to reboot server: Resource not found`),
		)
	})

	It("Fails if rebooting server results in an erroneous server state", func() {
		writeJsonParamToStdIn(`{
				"method":"reboot_vm",
				"arguments": ["error-server-state-id"],
				"api_version": 2
		}`)

		err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
		Expect(err).ShouldNot(HaveOccurred())

		_ = stdOutWriter.Close() //nolint:errcheck
		Expect(<-outChannel).To(
			ContainSubstring(`reboot_vm: compute_service: server became ERROR state while waiting to become ACTIVE"`),
		)
	})

})
