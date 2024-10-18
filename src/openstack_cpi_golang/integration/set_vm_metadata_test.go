package integration_test

import (
	"fmt"
	"net/http"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("SET VM METADATA", func() {

	BeforeEach(func() {
		SetupHTTP()

		Mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				fmt.Fprintf(w, `{
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

				fmt.Fprintf(w, `{
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
					}]
				}
			}`, Endpoint(), Endpoint(), Endpoint())
			}
		})

	})

	AfterEach(func() {
		TeardownHTTP()
	})

	Context("Positive cases: ", func() {

		BeforeEach(func() {
			Mux.HandleFunc("/v2.1/servers/server-id", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodGet:
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, `{
					"server": {
						"id": "server-id",
						"name": "old-name",
						"status": "ACTIVE"
					}
				}`)
				case http.MethodPut:
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, `{
						"server": {
							"id": "server-id",
							"name": "old-name",
							"status": "ACTIVE"
						}
				}`)

				}
			})

			Mux.HandleFunc("/v2.1/servers/server-id/metadata", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodGet:
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, `{
				   "server": {
					  "id": "server-id",
					  "name": "old-name",
					  "status": "ACTIVE"
				   }
					}`)
				case http.MethodPost:
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, `{
			   			"server": {
						"id": "server-id",
						"name": "old-name",
						"status": "ACTIVE"
					}
				}`)
				}
			})

			Mux.HandleFunc("/v2.1/servers/server-id/metadata/name", func(w http.ResponseWriter, r *http.Request) {

				fmt.Printf("---Called: Method: %s URI: %s ", r.Method, r.URL)

				switch r.Method {
				case http.MethodPut:
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, `{
						"server": {
							"id": "server-id",
							"name": "old-name",
							"status": "ACTIVE"
						}
				}`)
				}
			})

			Mux.HandleFunc("/v2.1/servers/server-id/metadata/job", func(w http.ResponseWriter, r *http.Request) {

				fmt.Printf("---Called: Method: %s URI: %s ", r.Method, r.URL)

				switch r.Method {
				case http.MethodPut:
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, `{
						"server": {
							"id": "server-id",
							"name": "old-name",
							"status": "ACTIVE"
						}
				}`)
				}
			})

			Mux.HandleFunc("/v2.1/servers/server-id/metadata/index", func(w http.ResponseWriter, r *http.Request) {

				fmt.Printf("---Called: Method: %s URI: %s ", r.Method, r.URL)

				switch r.Method {
				case http.MethodPut:
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, `{
						"server": {
							"id": "server-id",
							"name": "old-name",
							"status": "ACTIVE"
						}
				}`)
				}
			})

			Mux.HandleFunc("/v2.1/servers/server-id/metadata/compiling", func(w http.ResponseWriter, r *http.Request) {

				fmt.Printf("---Called: Method: %s URI: %s ", r.Method, r.URL)

				switch r.Method {
				case http.MethodPut:
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, `{
						"server": {
							"id": "server-id",
							"name": "old-name",
							"status": "ACTIVE"
						}
				}`)
				}
			})
		})

		It("sets a new servername successfully base on importing parameter 'name'", func() {
			writeJsonParamToStdIn(`{
				"method":"set_vm_metadata",
				"arguments": [
					"server-id",
					{
					"name": "new-name"
					}
				],
				"api_version": 2

			}`)

			config := getDefaultConfig(Endpoint())
			config.Cloud.Properties.Openstack.HumanReadableVMNames = true
			config.Cloud.Properties.Openstack.VM.Stemcell.APIVersion = 2

			err := cpi.Execute(config, logger)
			Expect(err).ShouldNot(HaveOccurred())

			stdOutWriter.Close()
			Expect(<-outChannel).To(ContainSubstring(`"result":null,"error":null`))
		})

		It("sets a new servername successfully base on importing parameter 'job/index'", func() {
			writeJsonParamToStdIn(`{
				"method":"set_vm_metadata",
				"arguments": [
					"server-id",
					{
					"job": "new-job",
					"index": "new-index"
					}
				],
				"api_version": 2

			}`)

			config := getDefaultConfig(Endpoint())
			config.Cloud.Properties.Openstack.HumanReadableVMNames = true
			config.Cloud.Properties.Openstack.VM.Stemcell.APIVersion = 2

			err := cpi.Execute(config, logger)
			Expect(err).ShouldNot(HaveOccurred())

			stdOutWriter.Close()
			Expect(<-outChannel).To(ContainSubstring(`"result":null,"error":null`))
		})

		It("sets a new servername successfully base on importing parameter 'compiling'", func() {
			writeJsonParamToStdIn(`{
				"method":"set_vm_metadata",
				"arguments": [
					"server-id",
					{
					"compiling": "new-compiling"
					}
				],
				"api_version": 2

			}`)

			config := getDefaultConfig(Endpoint())
			config.Cloud.Properties.Openstack.HumanReadableVMNames = true
			config.Cloud.Properties.Openstack.VM.Stemcell.APIVersion = 2

			err := cpi.Execute(config, logger)
			Expect(err).ShouldNot(HaveOccurred())

			stdOutWriter.Close()
			Expect(<-outChannel).To(ContainSubstring(`"result":null,"error":null`))
		})

		It("sets a new servername successfully base on importing parameter 'name' regardless of job/index/compiling", func() {
			writeJsonParamToStdIn(`{
				"method":"set_vm_metadata",
				"arguments": [
					"server-id",
					{
					"name": "new-name",
					"job": "new-job",
					"index": "new-index",
					"compiling": "new-compiling"
					}
				],
				"api_version": 2
			}`)

			config := getDefaultConfig(Endpoint())
			config.Cloud.Properties.Openstack.HumanReadableVMNames = true
			config.Cloud.Properties.Openstack.VM.Stemcell.APIVersion = 2

			err := cpi.Execute(config, logger)
			Expect(err).ShouldNot(HaveOccurred())

			stdOutWriter.Close()
			Expect(<-outChannel).To(ContainSubstring(`"result":null,"error":null`))
		})

		It("removes a key when one key map has null value", func() {
			writeJsonParamToStdIn(`{
				"method":"set_vm_metadata",
				"arguments": [
					"server-id",
					{
					"name": "new-name",
					"test": null
					}
				],
				"api_version": 2

			}`)

			config := getDefaultConfig(Endpoint())
			config.Cloud.Properties.Openstack.HumanReadableVMNames = true
			config.Cloud.Properties.Openstack.VM.Stemcell.APIVersion = 2

			err := cpi.Execute(config, logger)
			Expect(err).ShouldNot(HaveOccurred())

			stdOutWriter.Close()
			Expect(<-outChannel).To(ContainSubstring(`"result":null,"error":null`))
		})
	})

	Context("Failure in GetMetadata: ", func() {

		BeforeEach(func() {
			Mux.HandleFunc("/v2.1/servers/server", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodGet:
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, `{
						"server": {
							"ID": "get_meta_not_found",
							"name": "name"
						}
					}`)
				}
			})

			Mux.HandleFunc("/v2.1/servers/get_meta_not_found/metadata/Name", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodPut:
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, `{
							"server": {
								"ID": "get_meta_not_found",
								"name": "Name"
							}
					}`)
				}
			})

			Mux.HandleFunc("/v2.1/servers/get_meta_not_found/metadata/ID", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodPut:
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, `{
							"server": {
								"ID": "get_meta_not_found",
								"name": "Name"
							}
					}`)
				}
			})

			Mux.HandleFunc("/v2.1/servers/server/metadata", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodGet:
					w.WriteHeader(http.StatusUnauthorized)
					fmt.Fprintf(w, `{
						"server": {
							"ID": "get_meta_not_found",
							"name": "name"
						}
					}`)
				}
			})

		})

		It("returns error if getter server meta fails ", func() {
			writeJsonParamToStdIn(`{
					"method":"set_vm_metadata",
					"arguments": [
						"server",
						{
						"ID": "get_meta_not_found",
						"Name": "new-name"
						}
					],
					"api_version": 2
			}`)

			err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
			Expect(err).ShouldNot(HaveOccurred())

			stdOutWriter.Close()
			Expect(<-outChannel).To(ContainSubstring(`"message":"failed to get Metadata`))

		})
	})

	Context("Failure in DeleteServerMetaData: ", func() {

		BeforeEach(func() {

			Mux.HandleFunc("/v2.1/servers/server/metadata", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodGet:
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, `{
						"metadata": {
							"foo": "foo_value",
							"lbaas_pool_1": "pool_id_1/member_id_1",
							"lbaas_pool_2": "pool_id_2/member_id_not_existing",
							"test": "test"
						}
					}`)

				case http.MethodPost:
					w.WriteHeader(http.StatusBadRequest)
					fmt.Fprintf(w, `{
						"server": {
							"ID": "get_meta",
							"name": "name"
						}
					}`)
				}
			})

		})

		It("returns error if delete server meta fails", func() {
			writeJsonParamToStdIn(`{
				"method":"set_vm_metadata",
				"arguments": [
				   "server",
				   {
				   "id": "delete_meta_not_possible",
				   "name": "new-name",
				   "test": "test"
				   }
				],
				"api_version": 2
		  }`)

			err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
			Expect(err).ShouldNot(HaveOccurred())

			stdOutWriter.Close()
			Expect(<-outChannel).To(ContainSubstring(`"failed to delete Metadata`))

		})

	})

	Context("Failure in UpdateServerMetadata: ", func() {

		BeforeEach(func() {

			Mux.HandleFunc("/v2.1/servers/server/metadata", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodGet:
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, `{
							"metadata": {
								"foo": "foo_value",
								"lbaas_pool_1": "pool_id_1/member_id_1",
								"lbaas_pool_2": "pool_id_2/member_id_not_existing",
								"test": "test"
							}
						}`)

				case http.MethodPost:
					w.WriteHeader(http.StatusBadRequest)
				}
			})

		})

		It("returns error if delete server meta fails", func() {
			writeJsonParamToStdIn(`{
				"method":"set_vm_metadata",
				"arguments": [
					"server",
					{
					"name": "new-name",
					"id": "update_failed"
					}
				],
				"api_version": 2

			}`)

			config := getDefaultConfig(Endpoint())
			config.Cloud.Properties.Openstack.HumanReadableVMNames = true
			config.Cloud.Properties.Openstack.VM.Stemcell.APIVersion = 2

			err := cpi.Execute(config, logger)
			Expect(err).ShouldNot(HaveOccurred())

			stdOutWriter.Close()
			Expect(<-outChannel).To(ContainSubstring(`"message":"failed to update`))
		})

	})

	Context("Failure in UpdateServer: ", func() {

		BeforeEach(func() {
			Mux.HandleFunc("/v2.1/servers/server", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodGet:
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, `{
						"server": {
							"id": "update_failed",
							"name": "name"
						}
					}`)
				}
			})

			Mux.HandleFunc("/v2.1/servers/update_failed/metadata/name", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodPut:
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, `{
							"server": {
								"ID": "update_failed",
								"name": "Name"
							}
					}`)
				}
			})

			Mux.HandleFunc("/v2.1/servers/update_failed/metadata/id", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodPut:
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, `{
							"server": {
								"id": "get_meta_not_found",
								"name": "Name"
							}
					}`)
				}
			})

			Mux.HandleFunc("/v2.1/servers/server/metadata", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodGet:
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, `{
						"server": {
							"id": "update_failed",
							"name": "name"
						}
					}`)
				case http.MethodPost:
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, `{
						"server": {
							"id": "update_failed",
							"name": "name"
						}
					}`)
				}
			})

		})

		It("failed to update server name with importing 'name'", func() {
			writeJsonParamToStdIn(`{
				"method":"set_vm_metadata",
				"arguments": [
					"server",
					{
					"name": "new-name",
					"id": "update_failed"
					}
				],
				"api_version": 2

			}`)

			config := getDefaultConfig(Endpoint())
			config.Cloud.Properties.Openstack.HumanReadableVMNames = true
			config.Cloud.Properties.Openstack.VM.Stemcell.APIVersion = 2

			err := cpi.Execute(config, logger)
			Expect(err).ShouldNot(HaveOccurred())

			stdOutWriter.Close()
			Expect(<-outChannel).To(ContainSubstring(`"message":"failed to update`))
		})

	})

})
