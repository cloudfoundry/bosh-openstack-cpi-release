package integration_test

import (
	"fmt"
	"net/http"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/loadbalancer"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Delete VM", func() {
	var getServerCount = 0

	var defaultServerResponse = func(r *http.Request, w http.ResponseWriter, serverId string) {
		switch r.Method {
		case http.MethodDelete:
			w.WriteHeader(http.StatusNoContent)
			fmt.Fprintf(w, `{}`)

		case http.MethodGet:
			getServerCount++
			switchCase := getServerCount % 2

			w.WriteHeader(http.StatusOK)

			switch switchCase {
			case 1:
				fmt.Fprintf(w, `{
					"server": {
						"id": "%s",
						"status": "ACTIVE"
					}
				}`, serverId)
			case 0:
				fmt.Fprintf(w, `{
					"server": {
						"id": "%s",
						"status": "DELETED"
					}
				}`, serverId)
			}
		}
	}

	BeforeEach(func() {
		loadbalancer.LoadbalancerServicePollingInterval = 0
		compute.ComputeServicePollingInterval = 0

		SetupHTTP()

		MockAuthentication()

		Mux.HandleFunc("/v2.0/ports/1", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodDelete:
				w.WriteHeader(http.StatusNoContent)
				fmt.Fprintf(w, `{}`)
			}
		})

		Mux.HandleFunc("/v2.0/ports/wrong-port-id", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodDelete:
				w.WriteHeader(http.StatusNotFound)
				fmt.Fprintf(w, `{}`)
			}
		})

		Mux.HandleFunc("/v2.0/ports", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodDelete:
				w.WriteHeader(http.StatusNoContent)
				fmt.Fprintf(w, `{}`)

			case http.MethodGet:
				w.Header().Add("Content-Type", "application/json")
				w.WriteHeader(http.StatusOK)

				deviceID := r.URL.Query().Get("device_id")
				if deviceID != "1" && deviceID != "server_id_wrong_port" {
					fmt.Fprintf(w, `{
						"ports": []
					}`)
				}

				if deviceID == "1" {
					fmt.Fprintf(w, `{
						"ports": [
							{
								"device_id": "1",
								"id": "1"
							}
						]
					}`)
				} else if deviceID == "server_id_wrong_port" {
					fmt.Fprintf(w, `{
						"ports": [
							{
								"device_id": "server_id_wrong_port",
								"id": "1"
							},
							{
								"device_id": "server_id_wrong_port",
								"id": "wrong-port-id"
							}
						]
					}`)
				}
			}
		})

		Mux.HandleFunc("/v2.1/servers/1", func(w http.ResponseWriter, r *http.Request) {
			defaultServerResponse(r, w, "1")
		})

		Mux.HandleFunc("/v2.1/servers/1/metadata", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.WriteHeader(http.StatusOK)

				fmt.Fprintf(w, `{
					"metadata": {
						"foo": "foo_value",
						"lbaas_pool_1": "pool_id_1/member_id_1",
						"lbaas_pool_2": "pool_id_1/member_id_not_existing"
					}
				}`)
			}
		})

		Mux.HandleFunc("/v2.1/servers/server_id_wrong_port", func(w http.ResponseWriter, r *http.Request) {
			defaultServerResponse(r, w, "server_id_wrong_port")
		})

		Mux.HandleFunc("/v2.1/servers/server_id_poolmember_deletion_error", func(w http.ResponseWriter, r *http.Request) {
			defaultServerResponse(r, w, "server_id_poolmember_deletion_error")
		})

		Mux.HandleFunc("/v2.1/servers/server_id_poolmember_deletion_error/metadata", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.WriteHeader(http.StatusOK)

				fmt.Fprintf(w, `{
					"metadata": {
						"lbaas_pool_1": "pool_id_1/member_id_1",
						"lbaas_pool_3": "pool_id_1/member_id_error"
					}
				}`)
			}
		})

		Mux.HandleFunc("/v2.1/servers/server_id_deleted_inbetween", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodDelete:
				w.WriteHeader(http.StatusNotFound)
				fmt.Fprintf(w, `{}`)

			case http.MethodGet:
				getServerCount++
				switchCase := getServerCount % 2

				switch switchCase {
				case 1:
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, `{
						"server": {
							"id": "1",
							"status": "ACTIVE"
						}
					}`)
				case 0:
					w.WriteHeader(http.StatusNotFound)
					fmt.Fprintf(w, `{}`)
				}
			}
		})

		Mux.HandleFunc("/v2.1/servers/server_id_timeout_lbas", func(w http.ResponseWriter, r *http.Request) {
			defaultServerResponse(r, w, "server_id_timeout_lbas")
		})

		Mux.HandleFunc("/v2.1/servers/server_id_timeout_lbas/metadata", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.WriteHeader(http.StatusOK)

				fmt.Fprintf(w, `{
					"metadata": {
						"foo": "foo_value",
						"lbaas_pool_id_timeout": "pool_id_timeout/member_id_1"
					}
				}`)
			}
		})

		Mux.HandleFunc("/v2.1/servers/wrong-vm-id", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.WriteHeader(http.StatusNotFound)
				fmt.Fprintf(w, `{}`)
			}
		})

		Mux.HandleFunc("/v2.0/lbaas/pools/pool_id_1", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.WriteHeader(http.StatusOK)

				fmt.Fprintf(w, `{
					"pool": {
						"id": "pool_id_1",
						"loadbalancers": [{"id": "lbas_id_1"}],
						"listeners": [{"id": "listener_id_1"}]
					}
				}`)
			}
		})

		Mux.HandleFunc("/v2.0/lbaas/pools/pool_id_timeout", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.WriteHeader(http.StatusOK)

				fmt.Fprintf(w, `{
					"pool": {
						"id": "pool_id_timeout",
						"loadbalancers": [{"id": "lbas_id_timeout"}]
					}
				}`)
			}
		})

		Mux.HandleFunc("/v2.0/lbaas/pools/pool_id_1/members/member_id_1", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodDelete:
				w.WriteHeader(http.StatusNoContent)

				fmt.Fprintf(w, `{}`)
			}
		})

		Mux.HandleFunc("/v2.0/lbaas/pools/pool_id_1/members/member_id_not_existing", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodDelete:
				w.WriteHeader(http.StatusNotFound)

				fmt.Fprintf(w, `{}`)
			}
		})

		Mux.HandleFunc("/v2.0/lbaas/pools/pool_id_1/members/member_id_error", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodDelete:
				w.WriteHeader(http.StatusInternalServerError)

				fmt.Fprintf(w, `{}`)
			}
		})

		Mux.HandleFunc("/v2.0/lbaas/loadbalancers/lbas_id_1", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.WriteHeader(http.StatusOK)

				fmt.Fprintf(w, `{
					"loadbalancer": {
						"id": "lbas_id_1",
						"provisioning_status": "ACTIVE"
					}
				}`)
			}
		})

		Mux.HandleFunc("/v2.0/lbaas/loadbalancers/lbas_id_timeout", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.WriteHeader(http.StatusOK)

				fmt.Fprintf(w, `{
					"loadbalancer": {
						"id": "lbas_id_timeout",
						"provisioning_status": "PENDING_UPDATE"
					}
				}`)
			}
		})
	})

	AfterEach(func() {
		TeardownHTTP()
	})

	It("deletes a vm", func() {
		writeJsonParamToStdIn(`{
			"method": "delete_vm",
			"arguments": ["1"],
			"api_version": 2
		}`)

		err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
		Expect(err).ShouldNot(HaveOccurred())

		stdOutWriter.Close()
		Expect(<-outChannel).To(ContainSubstring(`"result":null,"error":null`))
	})

	It("times out waiting for the load balancer to become ACTIVE", func() {
		writeJsonParamToStdIn(`{
			"method": "delete_vm",
			"arguments": ["server_id_timeout_lbas"],
			"api_version": 2
		}`)

		cpiConfig := getDefaultConfig(Endpoint())

		err := cpi.Execute(cpiConfig, logger)
		Expect(err).ShouldNot(HaveOccurred())

		stdOutWriter.Close()
		Expect(<-outChannel).To(ContainSubstring(`message":"delete_vm: failed while waiting for loadbalancer to become active: timeout while waiting for loadbalancer 'lbas_id_timeout'`))
	})

	It("does not fail when deleting not-existing vm", func() {
		writeJsonParamToStdIn(`{
			"method": "delete_vm",
			"arguments": ["wrong-vm-id"],
			"api_version": 2
		}`)

		err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
		Expect(err).ShouldNot(HaveOccurred())

		stdOutWriter.Close()
		Expect(<-outChannel).To(ContainSubstring(`"result":null,"error":null`))
	})

	It("does not fail when deleting a vm with not-existing port", func() {
		writeJsonParamToStdIn(`{
			"method": "delete_vm",
			"arguments": ["server_id_wrong_port"],
			"api_version": 2
		}`)

		err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
		Expect(err).ShouldNot(HaveOccurred())

		stdOutWriter.Close()
		Expect(<-outChannel).To(ContainSubstring(`"result":null,"error":null`))
	})

	It("does not fail when deleting a vm which no longer exists", func() {
		writeJsonParamToStdIn(`{
			"method": "delete_vm",
			"arguments": ["server_id_deleted_inbetween"],
			"api_version": 2
		}`)

		err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
		Expect(err).ShouldNot(HaveOccurred())

		stdOutWriter.Close()
		Expect(<-outChannel).To(ContainSubstring(`"result":null,"error":null`))
	})

	It("raises an error if it fails to delete pool member", func() {
		writeJsonParamToStdIn(`{
			"method": "delete_vm",
			"arguments": ["server_id_poolmember_deletion_error"],
			"api_version": 2
		}`)

		cpiConfig := getDefaultConfig(Endpoint())

		err := cpi.Execute(cpiConfig, logger)
		Expect(err).ShouldNot(HaveOccurred())

		stdOutWriter.Close()
		Expect(<-outChannel).To(ContainSubstring(`message":"delete_vm: failed to delete pool member: max retry attempts (10) reached, err: Internal Server Error`))
	})
})
