package integration_test

import (
	"fmt"
	"net/http"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("HAS VM", func() {
	BeforeEach(func() {
		SetupHTTP()

		MockAuthentication()

		Mux.HandleFunc("/v2.1/servers/active-server-id", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.WriteHeader(http.StatusOK)
				fmt.Fprintf(w, `{
					"server": {
						"id": "active-server-id",
						"status": "ACTIVE"
					}
				}`)
			}
		})

		Mux.HandleFunc("/v2.1/servers/deleted-server-id", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.WriteHeader(http.StatusOK)
				fmt.Fprintf(w, `{
					"server": {
						"id": "deleted-server-id",
						"status": "DELETED"
					}
				}`)
			}
		})

		Mux.HandleFunc("/v2.1/servers/terminated-server-id", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.WriteHeader(http.StatusOK)
				fmt.Fprintf(w, `{
					"server": {
						"id": "terminated-server-id",
						"status": "TERMINATED"
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

		Mux.HandleFunc("/v2.1/servers/error-vm-id", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.WriteHeader(http.StatusInternalServerError)
				fmt.Fprintf(w, `{}`)
			}
		})

	})

	AfterEach(func() {
		TeardownHTTP()
	})

	It("returns true if the server exists and is ACTIVE", func() {
		writeJsonParamToStdIn(`{
				"method":"has_vm",
				"arguments": ["active-server-id"],
				"api_version": 2
		}`)

		err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
		Expect(err).ShouldNot(HaveOccurred())

		stdOutWriter.Close()
		Expect(<-outChannel).To(ContainSubstring(`"result":true,"error":null`))
	})

	It("returns false if the server exists and is DELETED", func() {
		writeJsonParamToStdIn(`{
				"method":"has_vm",
				"arguments": ["deleted-server-id"],
				"api_version": 2
		}`)

		err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
		Expect(err).ShouldNot(HaveOccurred())

		stdOutWriter.Close()
		Expect(<-outChannel).To(ContainSubstring(`"result":false,"error":null`))
	})

	It("returns false if the server exists and is TERMINATED", func() {
		writeJsonParamToStdIn(`{
				"method":"has_vm",
				"arguments": ["terminated-server-id"],
				"api_version": 2
		}`)

		err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
		Expect(err).ShouldNot(HaveOccurred())

		stdOutWriter.Close()
		Expect(<-outChannel).To(ContainSubstring(`"result":false,"error":null`))
	})

	It("returns false if the server does not exist", func() {
		writeJsonParamToStdIn(`{
				"method":"has_vm",
				"arguments": ["wrong-vm-id"],
				"api_version": 2
		}`)

		err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
		Expect(err).ShouldNot(HaveOccurred())

		stdOutWriter.Close()
		Expect(<-outChannel).To(ContainSubstring(`"result":false,"error":null`))
	})

	It("returns false and raises an error if server retrieval fails", func() {
		writeJsonParamToStdIn(`{
				"method":"has_vm",
				"arguments": ["error-vm-id"],
				"api_version": 2
		}`)

		cpiConfig := getDefaultConfig(Endpoint())
		cpiConfig.Cloud.Properties.RetryConfig = config.RetryConfigMap{
			"default": config.RetryConfig{
				MaxAttempts:   10,
				SleepDuration: 0,
			},
		}

		err := cpi.Execute(cpiConfig, logger)
		Expect(err).ShouldNot(HaveOccurred())

		stdOutWriter.Close()
		Expect(<-outChannel).To(ContainSubstring(`message":"has_vm: failed to retrieve server information: max retry attempts (10) reached, err: Internal Server Error`))
	})

})
