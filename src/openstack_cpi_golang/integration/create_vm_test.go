package integration_test

import (
	"fmt"
	"net/http"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/loadbalancer"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Create VM", func() {

	BeforeEach(func() {
		SetupHTTP()

		MockAuthentication()

		loadbalancer.LoadbalancerServicePollingInterval = 0
		compute.ComputeServicePollingInterval = 0

		Mux.HandleFunc("/v2/images/5bba0da5-dfb3-49d8-a005-d799507518f7", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.WriteHeader(http.StatusOK)

				fmt.Fprintf(w, `{
					"status": "active",
					"visibility": "private",
					"id": "b2173dd3-7ad6-4362-baa6-a68bce3565cb",
					"file": "/v2/images/b2173dd3-7ad6-4362-baa6-a68bce3565cb/file",
					"schema": "/v2/schemas/image"
				}`)
			}
		})

		Mux.HandleFunc("/v2.0/security-groups/0c8a5d1a-8922-4d65-a0b2-dd78ab869e04", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.Header().Add("Content-Type", "application/json")
				w.WriteHeader(http.StatusOK)

				fmt.Fprintf(w, `{
					"security_group": {
						"id": "85cc3048-abc3-43cc-89b3-377341426ac5"
					}
				}`)
			}
		})

		Mux.HandleFunc("/v2.0/security-groups/bosh_acceptance_tests", func(w http.ResponseWriter, r *http.Request) {
			w.Header().Add("Content-Type", "application/json")
			w.WriteHeader(http.StatusNotFound)
		})

		Mux.HandleFunc("/v2.0/security-groups", func(w http.ResponseWriter, r *http.Request) {
			w.Header().Add("Content-Type", "application/json")
			w.WriteHeader(http.StatusOK)

			fmt.Fprintf(w, `{
				"security_groups": [
					{
						"id": "191e4194-1b33-4886-8b2e-4a4e5de3f9ff",
						"name": "bosh_acceptance_tests"
					}
				]
			}`)
		})

		Mux.HandleFunc("/v2.1/os-keypairs/default_key_name", func(w http.ResponseWriter, r *http.Request) {
			w.Header().Add("Content-Type", "application/json")
			w.WriteHeader(http.StatusOK)

			fmt.Fprintf(w, `{
				"keypair": {
					"name": "default_key_name",
					"id": 1
				}
			}`)
		})

		Mux.HandleFunc("/v2.0/subnets", func(w http.ResponseWriter, r *http.Request) {
			if r.URL.Query().Get("network_id") != "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3" {
				w.WriteHeader(http.StatusNotFound)
				return
			}

			w.Header().Add("Content-Type", "application/json")
			w.WriteHeader(http.StatusOK)

			fmt.Fprintf(w, `{
				"subnets": [
					{
						"cidr": "10.0.11.0/24",
						"id": "08eae331-0402-425a-923c-34f7cfe39c1b"
					}
				]
			}`)

		})
	})

	AfterEach(func() {
		TeardownHTTP()
	})

	Context("when a vm is not created", func() {
		Context("when getting an image", func() {
			It("fails if an image does not exist", func() {
				Mux.HandleFunc("/v2/images/not-existing-image-id", func(w http.ResponseWriter, r *http.Request) {
					w.WriteHeader(http.StatusNotFound)
				})

				writeJsonParamToStdIn(`{
			"method": "create_vm",
			"arguments": [
				"a694d798-0b41-4255-9c8e-b282cd504a52", "not-existing-image-id",
				{}, {}, [], {}
			],
			"api_version": 2
		}`)

				err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
				Expect(err).ShouldNot(HaveOccurred())

				stdOutWriter.Close()
				Expect(<-outChannel).To(ContainSubstring("could not find the image 'not-existing-image-id' in OpenStack"))
			})

			It("fails if an image is not active", func() {
				Mux.HandleFunc("/v2/images/not-active-image-id", func(w http.ResponseWriter, r *http.Request) {
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, `{
					"status": "deleted"
				}`)
				})

				writeJsonParamToStdIn(`{
			"method": "create_vm",
			"arguments": [
				"a694d798-0b41-4255-9c8e-b282cd504a52", "not-active-image-id",
				{}, {},	[],	{}
			],
			"api_version": 2
		}`)

				err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
				Expect(err).ShouldNot(HaveOccurred())

				stdOutWriter.Close()
				Expect(<-outChannel).To(ContainSubstring("image 'not-active-image-id' is not in active state, it is in state: deleted"))
			})
		})

		Context("when getting network configuration", func() {
			It("fails if a manual network has no net_id", func() {
				writeJsonParamToStdIn(`{
			"method": "create_vm",
			"arguments": [
				"a694d798-0b41-4255-9c8e-b282cd504a52", "5bba0da5-dfb3-49d8-a005-d799507518f7", {},
				{
					"bosh": {
						"type": "manual",
						"cloud_properties": {
							"availability_zone":"z1"
						}
					}
				},
				[], {}
			],
			"api_version": 2
		}`)

				err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
				Expect(err).ShouldNot(HaveOccurred())

				stdOutWriter.Close()
				Expect(<-outChannel).To(ContainSubstring("failed to create network config: invalid manual network configuration: manual network must have a net_id"))
			})

			It("fails if multiple manual networks is used with 'openstack.use_dhcp=true'", func() {
				writeJsonParamToStdIn(`{
				"method": "create_vm",
				"arguments": [
					"a694d798-0b41-4255-9c8e-b282cd504a52", "5bba0da5-dfb3-49d8-a005-d799507518f7", {},
					{
						"bosh": {
							"type": "manual",
							"cloud_properties": {
								"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3"
							}
						},
						"another_network": {
							"type": "manual",
							"cloud_properties": {
								"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf4"
							}
						}
					},
					[], {}
				],
				"api_version": 2
			}`)

				defaultConfig = getDefaultConfig(Endpoint())
				defaultConfig.Cloud.Properties.Openstack.UseDHCP = true
				err := cpi.Execute(defaultConfig, logger)
				Expect(err).ShouldNot(HaveOccurred())

				stdOutWriter.Close()
				Expect(<-outChannel).To(ContainSubstring("multiple manual networks can only be used with"))
			})

			It("fails if multiple manual networks is used with an non-empty ConfigDrive", func() {
				writeJsonParamToStdIn(`{
				"method": "create_vm",
				"arguments": [
					"a694d798-0b41-4255-9c8e-b282cd504a52", "5bba0da5-dfb3-49d8-a005-d799507518f7", {},
					{
						"bosh": {
							"type": "manual",
							"cloud_properties": {
								"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3"
							}
						},
						"another_network": {
							"type": "manual",
							"cloud_properties": {
								"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf4"
							}
						}
					},
					[], {}
				],
				"api_version": 2
			}`)

				defaultConfig = getDefaultConfig(Endpoint())
				defaultConfig.Cloud.Properties.Openstack.ConfigDrive = "cdrom"
				err := cpi.Execute(defaultConfig, logger)
				Expect(err).ShouldNot(HaveOccurred())

				stdOutWriter.Close()
				Expect(<-outChannel).To(ContainSubstring("multiple manual networks can only be used with"))
			})

			It("fails when configuring multiple dynamic networks", func() {
				writeJsonParamToStdIn(`{
				"method": "create_vm",
				"arguments": [
					"a694d798-0b41-4255-9c8e-b282cd504a52", "5bba0da5-dfb3-49d8-a005-d799507518f7", {},
					{
						"bosh": {
							"type": "dynamic",
							"cloud_properties": {
								"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3"
							}
						},
						"another_network": {
							"type": "dynamic",
							"cloud_properties": {
								"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf4"
							}
						}
					},
					[], {}
				],
				"api_version": 2
			}`)

				defaultConfig = getDefaultConfig(Endpoint())
				defaultConfig.Cloud.Properties.Openstack.ConfigDrive = "cdrom"
				err := cpi.Execute(defaultConfig, logger)
				Expect(err).ShouldNot(HaveOccurred())

				stdOutWriter.Close()
				Expect(<-outChannel).To(ContainSubstring("only one dynamic should be defined per instance"))
			})

			It("fails when configuring multiple vip networks", func() {
				writeJsonParamToStdIn(`{
				"method": "create_vm",
				"arguments": [
					"a694d798-0b41-4255-9c8e-b282cd504a52", "5bba0da5-dfb3-49d8-a005-d799507518f7", {},
					{
						"bosh": {
							"type": "vip",
							"cloud_properties": {
								"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3"
							}
						},
						"another_network": {
							"type": "vip",
							"cloud_properties": {
								"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf4"
							}
						}
					},
					[], {}
				],
				"api_version": 2
			}`)

				defaultConfig = getDefaultConfig(Endpoint())
				defaultConfig.Cloud.Properties.Openstack.ConfigDrive = "cdrom"
				err := cpi.Execute(defaultConfig, logger)
				Expect(err).ShouldNot(HaveOccurred())

				stdOutWriter.Close()
				Expect(<-outChannel).To(ContainSubstring("only one vip should be defined per instance"))
			})

			It("fails when a network has no net_id", func() {
				writeJsonParamToStdIn(`{
			"method": "create_vm",
			"arguments": [
				"a694d798-0b41-4255-9c8e-b282cd504a52", "5bba0da5-dfb3-49d8-a005-d799507518f7", {},
				{
					"bosh": {
						"type": "manual",
						"cloud_properties": {
							"availability_zone":"z1"
						}
					}
				},
				[], {}
			],
			"api_version": 2
		}`)

				err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
				Expect(err).ShouldNot(HaveOccurred())

				stdOutWriter.Close()
				Expect(<-outChannel).To(ContainSubstring("failed to create network config: invalid manual network configuration: manual network must have a net_id"))
			})

			It("fails if a security rule cannot be resolved", func() {
				writeJsonParamToStdIn(`{
			"method": "create_vm",
			"arguments": [
				"a694d798-0b41-4255-9c8e-b282cd504a52", "5bba0da5-dfb3-49d8-a005-d799507518f7", {},
				{
					"bosh": {
						"type": "manual",
						"ip": "10.0.11.16",
						"netmask": "255.255.255.0",
						"cloud_properties": {
							"availability_zone":"z1",
							"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3",
							"security_groups": [
								"not-exiting-group"
							]
						},
						"default": [
							"dns",
							"gateway"
						],
						"gateway": "10.0.11.1"
					}
				},
				[], {}
			],
			"api_version": 2
		}`)

				err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
				Expect(err).ShouldNot(HaveOccurred())

				stdOutWriter.Close()
				Expect(<-outChannel).To(ContainSubstring("failed to resolve security group: could not resolve security group 'not-exiting-group'"))
			})
		})

		Context("when creating ports for manual networks", func() {
			It("handles conflicting ports and fails if port can not be created", func() {
				Mux.HandleFunc("/v2.0/ports", func(w http.ResponseWriter, r *http.Request) {
					switch r.Method {
					case http.MethodGet:
						w.Header().Add("Content-Type", "application/json")
						w.WriteHeader(http.StatusOK)
						fmt.Fprintf(w, `{
						"port": {
							"id": "65c0ee9f-d634-4522-8954-51021b570b0d",
							"status": "DOWN"
						}
					}`)

					case http.MethodPost:
						w.Header().Add("Content-Type", "application/json")
						w.WriteHeader(http.StatusForbidden)

						fmt.Fprintf(w, `{}`)
					}
				})

				Mux.HandleFunc("/v2.0/ports/65c0ee9f-d634-4522-8954-51021b570b0d", func(w http.ResponseWriter, r *http.Request) {
					switch r.Method {
					case http.MethodDelete:
						w.WriteHeader(http.StatusNoContent)

						fmt.Fprintf(w, `{}`)
					}
				})

				writeJsonParamToStdIn(`{
				"method": "create_vm",
				"arguments": [
					"a694d798-0b41-4255-9c8e-b282cd504a52",
					"5bba0da5-dfb3-49d8-a005-d799507518f7",
					{
						"instance_type": "m1.tiny",
						"key_name": "default_key_name",
						"availability_zones": ["z1"]
					},
					{
						"bosh": {
							"type": "manual",
							"ip": "10.0.11.16",
							"netmask": "255.255.255.0",
							"cloud_properties": {
								"availability_zone": "z1",
								"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3",
								"security_groups": [
									"0c8a5d1a-8922-4d65-a0b2-dd78ab869e04",
									"bosh_acceptance_tests"
								]
							},
							"default": [
								"dns",
								"gateway"
							],
							"gateway": "10.0.11.1"
						}
					},
					[],
					{}
				],
				"api_version": 2
			}`)

				err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
				Expect(err).ShouldNot(HaveOccurred())

				stdOutWriter.Close()
				Expect(<-outChannel).To(ContainSubstring("failed to recreate port on network 'fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3' for ip '10.0.11.16' Request forbidden"))
			})

			It("fails if allowed_address_pairs are not empty and vrrp_port_check is set to true but no port exists", func() {
				Mux.HandleFunc("/v2.0/ports", func(w http.ResponseWriter, r *http.Request) {
					switch r.Method {
					case http.MethodGet:
						w.Header().Add("Content-Type", "application/json")
						w.WriteHeader(http.StatusOK)
						fmt.Fprintf(w, `{"ports": []}`)

					case http.MethodPost:
						w.Header().Add("Content-Type", "application/json")
						w.WriteHeader(http.StatusCreated)

						fmt.Fprintf(w, `{
					"port": {
						"id": "65c0ee9f-d634-4522-8954-51021b570b0d",
						"status": "ACTIVE"
					}
				}`)
					}
				})

				writeJsonParamToStdIn(`{
				"method": "create_vm",
				"arguments": [
					"a694d798-0b41-4255-9c8e-b282cd504a52",
					"5bba0da5-dfb3-49d8-a005-d799507518f7",
					{
						"instance_type": "m1.tiny",
						"key_name": "default_key_name",
						"availability_zones": ["z1"],
						"allowed_address_pairs": "198.51.100.221",
						"vrrp_port_check": true
					},
					{
						"bosh": {
							"type": "manual",
							"ip": "10.0.11.16",
							"netmask": "255.255.255.0",
							"cloud_properties": {
								"availability_zone": "z1",
								"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3",
								"security_groups": [
									"0c8a5d1a-8922-4d65-a0b2-dd78ab869e04",
									"bosh_acceptance_tests"
								]
							},
							"default": [
								"dns",
								"gateway"
							],
							"gateway": "10.0.11.1"
						}
					},
					[],
					{}
				],
				"api_version": 2
			}`)

				err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
				Expect(err).ShouldNot(HaveOccurred())

				stdOutWriter.Close()
				Expect(<-outChannel).To(ContainSubstring("failed create network opts: configured VRRP port with ip '198.51.100.221' does not exist"))
			})
		})

		Context("when creating a server", func() {
			BeforeEach(func() {
				Mux.HandleFunc("/v2.1/servers", func(w http.ResponseWriter, r *http.Request) {
					switch r.Method {
					case http.MethodGet:
						w.WriteHeader(http.StatusAccepted)

						fmt.Fprintf(w, `{
						"server": {
							"id": "f5dc173b-6804-445a-a6d8-c705dad5b5eb",
							"status": "ACTIVE"
						}
					}`)
					case http.MethodPost:
						w.WriteHeader(http.StatusBadRequest)
					}
				})

				Mux.HandleFunc("/v2.0/ports", func(w http.ResponseWriter, r *http.Request) {
					switch r.Method {
					case http.MethodGet:
						w.Header().Add("Content-Type", "application/json")
						w.WriteHeader(http.StatusOK)
						fmt.Fprintf(w, `{"ports": []}`)

					case http.MethodPost:
						w.Header().Add("Content-Type", "application/json")
						w.WriteHeader(http.StatusCreated)

						fmt.Fprintf(w, `{
							"port": {
								"id": "65c0ee9f-d634-4522-8954-51021b570b0d",
								"status": "ACTIVE"
							}
						}`)
					}
				})
			})

			Context("when flavor disk is not zero", func() {
				BeforeEach(func() {
					Mux.HandleFunc("/v2.1/flavors/detail", func(w http.ResponseWriter, r *http.Request) {
						w.Header().Add("Content-Type", "application/json")
						w.WriteHeader(http.StatusOK)

						fmt.Fprintf(w, `{
						"flavors": [
							{
								"disk": 1,
								"id": "1",
								"name": "m1.tiny",
								"ram": 512
							}
						]
					}`)
					})
				})

				It("fails if a wrong flavorName is given", func() {
					writeJsonParamToStdIn(`{
				"method": "create_vm",
				"arguments": [
					"a694d798-0b41-4255-9c8e-b282cd504a52",
					"5bba0da5-dfb3-49d8-a005-d799507518f7",
					{
						"instance_type": "wrong_flavor",
						"availability_zones": ["z1"]
					},
					{
						"bosh": {
							"type": "manual",
							"ip": "10.0.11.16",
							"netmask": "255.255.255.0",
							"cloud_properties": {
								"availability_zone": "z1",
								"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3",
								"security_groups": [
									"0c8a5d1a-8922-4d65-a0b2-dd78ab869e04"
								]
							},
							"default": [
								"dns",
								"gateway"
							],
							"gateway": "10.0.11.1"
						}
					},
					[],
					{}
				],
				"api_version": 2
			}`)

					err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
					Expect(err).ShouldNot(HaveOccurred())

					stdOutWriter.Close()
					Expect(<-outChannel).To(ContainSubstring("failed to resolve flavor of instance type 'wrong_flavor': flavor for instance type 'wrong_flavor' not found"))
				})

				It("fails if a key pair name cannot be resolved", func() {
					Mux.HandleFunc("/v2.1/os-keypairs/unknown_key_name", func(w http.ResponseWriter, r *http.Request) {
						w.Header().Add("Content-Type", "application/json")
						w.WriteHeader(http.StatusNotFound)
					})

					writeJsonParamToStdIn(`{
						"method": "create_vm",
						"arguments": [
							"a694d798-0b41-4255-9c8e-b282cd504a52",
							"5bba0da5-dfb3-49d8-a005-d799507518f7",
							{
								"instance_type": "m1.tiny",
								"availability_zones": ["z1"]
							},
							{
								"bosh": {
									"type": "manual",
									"ip": "10.0.11.16",
									"netmask": "255.255.255.0",
									"cloud_properties": {
										"availability_zone":"z1",
										"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3",
										"security_groups": [
											"0c8a5d1a-8922-4d65-a0b2-dd78ab869e04"
										]
									},
									"default": [
										"dns",
										"gateway"
									],
									"gateway": "10.0.11.1"
								}
							},
							[],
							{}
						],
						"api_version": 2
					}`)

					defaultConfig = getDefaultConfig(Endpoint())
					defaultConfig.Cloud.Properties.Openstack.DefaultKeyName = "unknown_key_name"

					err := cpi.Execute(defaultConfig, logger)
					Expect(err).ShouldNot(HaveOccurred())

					stdOutWriter.Close()
					Expect(<-outChannel).To(ContainSubstring("failed to resolve keypair: failed to retrieve 'unknown_key_name'"))
				})

				It("fails if create server raises an error in all availability zones", func() {
					writeJsonParamToStdIn(`{
					"method": "create_vm",
					"arguments": [
						"a694d798-0b41-4255-9c8e-b282cd504a52",
						"5bba0da5-dfb3-49d8-a005-d799507518f7",
						{
							"instance_type": "m1.tiny",
							"key_name": "default_key_name",
							"availability_zones": ["z1", "z2"]
						},
						{
							"bosh": {
								"type": "manual",
								"ip": "10.0.11.16",
								"netmask": "255.255.255.0",
								"cloud_properties": {
									"availability_zone": "z1",
									"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3",
									"security_groups": [
										"0c8a5d1a-8922-4d65-a0b2-dd78ab869e04",
										"bosh_acceptance_tests"
									]
								},
								"default": [
									"dns",
									"gateway"
								],
								"gateway": "10.0.11.1"
							}
						},
						[],
						{}
					],
					"api_version": 2
				}`)

					defaultConfig = getDefaultConfig(Endpoint())
					defaultConfig.Cloud.Properties.Openstack.IgnoreServerAvailabilityZone = true

					err := cpi.Execute(defaultConfig, logger)
					Expect(err).ShouldNot(HaveOccurred())

					stdOutWriter.Close()
					Expect(<-outChannel).To(ContainSubstring("failed to create server in availability zone"))
				})
			})

			Context("when flavor disk is zero", func() {
				BeforeEach(func() {
					Mux.HandleFunc("/v2.1/flavors/detail", func(w http.ResponseWriter, r *http.Request) {
						w.Header().Add("Content-Type", "application/json")
						w.WriteHeader(http.StatusOK)

						fmt.Fprintf(w, `{
					"flavors": [
						{
							"disk": 0,
							"id": "1",
							"name": "m1.tiny",
							"ram": 512
						}
					]
				}`)
					})
				})

				It("fails if root disk size and flavor disk size are 0", func() {

					writeJsonParamToStdIn(`{
				"method": "create_vm",
				"arguments": [
					"a694d798-0b41-4255-9c8e-b282cd504a52",
					"5bba0da5-dfb3-49d8-a005-d799507518f7",
					{
						"instance_type": "m1.tiny",
						"key_name": "default_key_name",
						"availability_zones": ["z1"]
					},
					{
						"bosh": {
							"type": "manual",
							"ip": "10.0.11.16",
							"netmask": "255.255.255.0",
							"cloud_properties": {
								"availability_zone": "z1",
								"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3",
								"security_groups": [
									"0c8a5d1a-8922-4d65-a0b2-dd78ab869e04",
									"bosh_acceptance_tests"
								]
							},
							"default": [
								"dns",
								"gateway"
							],
							"gateway": "10.0.11.1"
						}
					},
					[],
					{}
				],
				"api_version": 2
			}`)

					defaultConfig.Cloud.Properties.Openstack = config.OpenstackConfig{
						AuthURL:                 Endpoint(),
						Username:                "admin",
						APIKey:                  "admin",
						DomainName:              "domain",
						Tenant:                  "tenant",
						Region:                  "region",
						DefaultKeyName:          "unknown_key_name",
						StemcellPubliclyVisible: true,
					}

					err := cpi.Execute(defaultConfig, logger)
					Expect(err).ShouldNot(HaveOccurred())

					stdOutWriter.Close()
					Expect(<-outChannel).To(ContainSubstring("flavor '1' has a root disk size of 0. Either pick a different flavor or define root_disk.size in your VM cloud_properties"))
				})
			})
		})
	})

	Context("when a vm is created", func() {
		BeforeEach(func() {
			Mux.HandleFunc("/v2.1/servers", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodGet:
					w.WriteHeader(http.StatusAccepted)

					fmt.Fprintf(w, `{
					"server": {
						"id": "f5dc173b-6804-445a-a6d8-c705dad5b5eb",
						"status": "ACTIVE"
					}
				}`)
				case http.MethodPost:
					w.WriteHeader(http.StatusCreated)
					fmt.Fprintf(w, `{
					"server": {
						"id": "f5dc173b-6804-445a-a6d8-c705dad5b5eb"
					}
				}`)
				}
			})

			Mux.HandleFunc("/v2.1/flavors/detail", func(w http.ResponseWriter, r *http.Request) {
				w.Header().Add("Content-Type", "application/json")
				w.WriteHeader(http.StatusOK)

				fmt.Fprintf(w, `{
				"flavors": [
					{
						"disk": 1,
						"id": "1",
						"name": "m1.tiny",
						"ram": 512
					}
				]
			}`)
			})

			Mux.HandleFunc("/v2.0/ports", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodGet:
					w.Header().Add("Content-Type", "application/json")
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, `{
						"ports": [
							{
								"id": "65c0ee9f-d634-4522-8954-51021b570b0d",
								"status": "ACTIVE"
							}
						]
					}`)

				case http.MethodPost:
					w.Header().Add("Content-Type", "application/json")
					w.WriteHeader(http.StatusCreated)

					fmt.Fprintf(w, `{
						"port": {
							"id": "65c0ee9f-d634-4522-8954-51021b570b0d",
							"status": "ACTIVE"
						}
					}`)
				}
			})
		})

		Context("when in status ACTIVE", func() {
			BeforeEach(func() {
				Mux.HandleFunc("/v2.1/servers/f5dc173b-6804-445a-a6d8-c705dad5b5eb", func(w http.ResponseWriter, r *http.Request) {
					switch r.Method {
					case http.MethodGet:
						w.WriteHeader(http.StatusOK)

						fmt.Fprintf(w, `{
							"server": {
								"id": "f5dc173b-6804-445a-a6d8-c705dad5b5eb",
								"status": "ACTIVE"
							}
						}`)
					}
				})
			})

			Context("when it succeeds", func() {
				It("Creates a VM with the configured resources", func() {
					writeJsonParamToStdIn(`{
						"method": "create_vm",
						"arguments": [
							"a694d798-0b41-4255-9c8e-b282cd504a52",
							"5bba0da5-dfb3-49d8-a005-d799507518f7",
							{
								"instance_type": "m1.tiny",
								"key_name": "default_key_name",
								"availability_zones": ["z1"]
							},
							{
								"bosh": {
									"type": "manual",
									"ip": "10.0.11.16",
									"netmask": "255.255.255.0",
									"cloud_properties": {
										"availability_zone": "z1",
										"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3",
										"security_groups": [
											"0c8a5d1a-8922-4d65-a0b2-dd78ab869e04",
											"bosh_acceptance_tests"
										]
									},
									"default": [
										"dns",
										"gateway"
									],
									"gateway": "10.0.11.1"
								}
							},
							[],
							{}
						],
						"api_version": 2
					}`)

					err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
					Expect(err).ShouldNot(HaveOccurred())

					stdOutWriter.Close()
					Expect(<-outChannel).To(ContainSubstring(`"result":["f5dc173b-6804-445a-a6d8-c705dad5b5eb",{"bosh":{"type":"manual","ip":"10.0.11.16","netmask":"255.255.255.0","gateway":"10.0.11.1","dns":null,"default":["dns","gateway"],"routes":null,"cloud_properties":{"availability_zone":"z1","net_id":"fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3","security_groups":["0c8a5d1a-8922-4d65-a0b2-dd78ab869e04","bosh_acceptance_tests"]}}}],"error":null`))
				})
			})

			Context("when validating Cloud Properties", func() {
				It("succeeds if multiple availability zones are defined and setting ignore_server_availability_zone to true", func() {
					writeJsonParamToStdIn(`{
						"method": "create_vm",
						"arguments": [
							"a694d798-0b41-4255-9c8e-b282cd504a52",
							"5bba0da5-dfb3-49d8-a005-d799507518f7",
							{
								"instance_type": "m1.tiny",
								"key_name": "default_key_name",
								"availability_zones": ["z1", "z2"]
							},
							{
								"bosh": {
									"type": "manual",
									"ip": "10.0.11.16",
									"netmask": "255.255.255.0",
									"cloud_properties": {
										"availability_zone": "z1",
										"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3",
										"security_groups": [
											"0c8a5d1a-8922-4d65-a0b2-dd78ab869e04",
											"bosh_acceptance_tests"
										]
									},
									"default": [
										"dns",
										"gateway"
									],
									"gateway": "10.0.11.1"
								}
							},
							[],
							{}
						],
						"api_version": 2
					}`)

					defaultConfig = getDefaultConfig(Endpoint())
					defaultConfig.Cloud.Properties.Openstack.IgnoreServerAvailabilityZone = true
					err := cpi.Execute(defaultConfig, logger)
					Expect(err).ShouldNot(HaveOccurred())

					stdOutWriter.Close()
					Expect(<-outChannel).To(ContainSubstring(`"result":["f5dc173b-6804-445a-a6d8-c705dad5b5eb",{"bosh":{"type":"manual","ip":"10.0.11.16","netmask":"255.255.255.0","gateway":"10.0.11.1","dns":null,"default":["dns","gateway"],"routes":null,"cloud_properties":{"availability_zone":"z1","net_id":"fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3","security_groups":["0c8a5d1a-8922-4d65-a0b2-dd78ab869e04","bosh_acceptance_tests"]}}}],"error":null`))
				})

				It("fails if load balancer pool defined without a name", func() {
					writeJsonParamToStdIn(`{
						"method": "create_vm",
						"arguments": [
							"a694d798-0b41-4255-9c8e-b282cd504a52", "5bba0da5-dfb3-49d8-a005-d799507518f7",
							{
								"instance_type": "m1.tiny",
								"availability_zones": ["z1"],
								"loadbalancer_pools": [ { "name": "", "ProtocolPort": 80 } ]
							},
							{}, [], {}
						],
						"api_version": 2
					}`)

					err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
					Expect(err).ShouldNot(HaveOccurred())

					stdOutWriter.Close()
					Expect(<-outChannel).To(ContainSubstring("failed to validate cloud properties: load balancer pool defined without name"))
				})

				It("fails if load balancer pool defined without a valid ProtocolPort", func() {
					writeJsonParamToStdIn(`{
						"method": "create_vm",
						"arguments": [
							"a694d798-0b41-4255-9c8e-b282cd504a52", "5bba0da5-dfb3-49d8-a005-d799507518f7",
							{
								"instance_type": "m1.tiny",
								"availability_zones": ["z1"],
								"loadbalancer_pools": [ { "name": "myPool", "ProtocolPort": 0 } ]
							},
							{}, [], {}
						],
						"api_version": 2
					}`)

					err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
					Expect(err).ShouldNot(HaveOccurred())

					stdOutWriter.Close()
					Expect(<-outChannel).To(ContainSubstring("load balancer pool 'myPool' has no port definition"))
				})

				It("fails if multiple availability zone properties are defined", func() {
					writeJsonParamToStdIn(`{
						"method": "create_vm",
						"arguments": [
							"a694d798-0b41-4255-9c8e-b282cd504a52", "5bba0da5-dfb3-49d8-a005-d799507518f7",
							{
								"availability_zones": ["z1"],
								"availability_zone": "z2"
							},
							{}, [], {}
						],
						"api_version": 2
					}`)

					err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
					Expect(err).ShouldNot(HaveOccurred())

					stdOutWriter.Close()
					Expect(<-outChannel).To(ContainSubstring("only one property of 'availability_zone' and 'availability_zones' can be configured"))
				})

				It("fails if multiple availability zones are defined without setting ignore_server_availability_zone to true", func() {
					writeJsonParamToStdIn(`{
						"method": "create_vm",
						"arguments": [
							"a694d798-0b41-4255-9c8e-b282cd504a52", "5bba0da5-dfb3-49d8-a005-d799507518f7",
							{
								"availability_zones": ["z1", "z2"]
							},
							{}, [], {}
						],
						"api_version": 2
					}`)

					err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
					Expect(err).ShouldNot(HaveOccurred())

					stdOutWriter.Close()
					Expect(<-outChannel).To(ContainSubstring("cannot use multiple azs without 'openstack.ignore_server_availability_zone' set to true"))
				})
			})

			Context("when configuring VIP Networks", func() {
				It("configures a VIP Network", func() {
					Mux.HandleFunc("/v2.0/floatingips", func(w http.ResponseWriter, r *http.Request) {
						switch r.Method {
						case http.MethodGet:
							floatingip := r.URL.Query().Get("floating_ip_address")

							if floatingip == "10.0.11.16" {
								w.Header().Add("Content-Type", "application/json")
								w.WriteHeader(http.StatusOK)

								fmt.Fprintf(w, `{
									"floatingips": [
										{
											"id": "floating_ip_id_1"
										}
									]
								}`)
							}
						}
					})

					Mux.HandleFunc("/v2.0/floatingips/floating_ip_id_1", func(w http.ResponseWriter, r *http.Request) {
						switch r.Method {
						case http.MethodPut:
							w.Header().Add("Content-Type", "application/json")
							w.WriteHeader(http.StatusOK)

							fmt.Fprintf(w, `{
								"floatingips": [
									{
										"id": "floating_ip_id_1"
									}
								]
							}`)
						}
					})

					writeJsonParamToStdIn(`{
						"method": "create_vm",
						"arguments": [
							"a694d798-0b41-4255-9c8e-b282cd504a52",
							"5bba0da5-dfb3-49d8-a005-d799507518f7",
							{
								"instance_type": "m1.tiny",
								"key_name": "default_key_name",
								"availability_zones": ["z1"]
							},
							{
								"bosh": {
									"type": "vip",
									"ip": "10.0.11.16",
									"netmask": "255.255.255.0",
									"cloud_properties": {
										"availability_zone": "z1",
										"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3",
										"security_groups": [
											"0c8a5d1a-8922-4d65-a0b2-dd78ab869e04",
											"bosh_acceptance_tests"
										]
									},
									"default": [
										"dns",
										"gateway"
									],
									"gateway": "10.0.11.1"
								}
							},
							[],
							{}
						],
						"api_version": 2
					}`)

					err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
					Expect(err).ShouldNot(HaveOccurred())

					stdOutWriter.Close()
					Expect(<-outChannel).To(ContainSubstring(`"result":["f5dc173b-6804-445a-a6d8-c705dad5b5eb",{"bosh":{"type":"vip","ip":"10.0.11.16","netmask":"255.255.255.0","gateway":"10.0.11.1","dns":null,"default":["dns","gateway"],"routes":null,"cloud_properties":{"availability_zone":"z1","net_id":"fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3","security_groups":["0c8a5d1a-8922-4d65-a0b2-dd78ab869e04","bosh_acceptance_tests"]}}}],"error":null`))
				})

				It("fails if a floating ip can not be associated", func() {
					Mux.HandleFunc("/v2.0/floatingips", func(w http.ResponseWriter, r *http.Request) {
						switch r.Method {
						case http.MethodGet:
							floatingip := r.URL.Query().Get("floating_ip_address")

							if floatingip == "10.0.11.16" {
								w.Header().Add("Content-Type", "application/json")
								w.WriteHeader(http.StatusOK)

								fmt.Fprintf(w, `{
									"floatingips": [
										{
											"id": "floating_ip_id_1"
										}
									]
								}`)
							}
						}
					})

					Mux.HandleFunc("/v2.0/floatingips/floating_ip_id_1", func(w http.ResponseWriter, r *http.Request) {
						switch r.Method {
						case http.MethodPut:
							w.Header().Add("Content-Type", "application/json")
							w.WriteHeader(http.StatusBadRequest)
						}
					})

					writeJsonParamToStdIn(`{
						"method": "create_vm",
						"arguments": [
							"a694d798-0b41-4255-9c8e-b282cd504a52",
							"5bba0da5-dfb3-49d8-a005-d799507518f7",
							{
								"instance_type": "m1.tiny",
								"key_name": "default_key_name",
								"availability_zones": ["z1"]
							},
							{
								"bosh": {
									"type": "vip",
									"ip": "10.0.11.16",
									"netmask": "255.255.255.0",
									"cloud_properties": {
										"availability_zone": "z1",
										"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3",
										"security_groups": [
											"0c8a5d1a-8922-4d65-a0b2-dd78ab869e04",
											"bosh_acceptance_tests"
										]
									},
									"default": [
										"dns",
										"gateway"
									],
									"gateway": "10.0.11.1"
								}
							},
							[],
							{}
						],
						"api_version": 2
					}`)

					err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
					Expect(err).ShouldNot(HaveOccurred())

					stdOutWriter.Close()
					Expect(<-outChannel).To(ContainSubstring(`failed to associate floating ip to port`))
				})

				It("fails if no floating ips are allocated", func() {
					Mux.HandleFunc("/v2.0/floatingips", func(w http.ResponseWriter, r *http.Request) {
						switch r.Method {
						case http.MethodGet:
							w.Header().Add("Content-Type", "application/json")
							w.WriteHeader(http.StatusOK)

							fmt.Fprintf(w, `{
								"floatingips": []
							}`)

						}
					})

					writeJsonParamToStdIn(`{
						"method": "create_vm",
						"arguments": [
							"a694d798-0b41-4255-9c8e-b282cd504a52",
							"5bba0da5-dfb3-49d8-a005-d799507518f7",
							{
								"instance_type": "m1.tiny",
								"key_name": "default_key_name",
								"availability_zones": ["z1"]
							},
							{
								"bosh": {
									"type": "vip",
									"ip": "10.0.11.16",
									"netmask": "255.255.255.0",
									"cloud_properties": {
										"availability_zone": "z1",
										"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3",
										"security_groups": [
											"0c8a5d1a-8922-4d65-a0b2-dd78ab869e04",
											"bosh_acceptance_tests"
										]
									},
									"default": [
										"dns",
										"gateway"
									],
									"gateway": "10.0.11.1"
								}
							},
							[],
							{}
						],
						"api_version": 2
					}`)

					err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
					Expect(err).ShouldNot(HaveOccurred())

					stdOutWriter.Close()
					Expect(<-outChannel).To(ContainSubstring(`failed to get floating IP: floating IP 10.0.11.16 not allocated`))
				})
			})

			Context("when configuring load balancer pools", func() {
				It("create pool members for provided load balancer pools", func() {
					Mux.HandleFunc("/v2.0/lbaas/pools", func(w http.ResponseWriter, r *http.Request) {
						if r.Method != http.MethodGet || r.URL.Query().Get("name") != "myPool" {
							w.WriteHeader(http.StatusNotFound)
							return
						}

						w.Header().Add("Content-Type", "application/json")
						w.WriteHeader(http.StatusOK)

						fmt.Fprintf(w, `{
							"pools": [
								{
									"id": "pool_id_1",
									"name": "myPool",
									"loadbalancers": [{"id": "the-lb-id"}]
								}
							]
						}`)

					})

					Mux.HandleFunc("/v2.0/lbaas/loadbalancers/the-lb-id", func(w http.ResponseWriter, r *http.Request) {
						if r.Method != http.MethodGet {
							w.WriteHeader(http.StatusNotFound)
							return
						}

						w.WriteHeader(http.StatusOK)

						fmt.Fprintf(w, `{
							"loadbalancer": {
								"id": "the-lb-id",
								"provisioning_status": "ACTIVE"
							}
						}`)
					})

					Mux.HandleFunc("/v2.0/lbaas/pools/pool_id_1/members", func(w http.ResponseWriter, r *http.Request) {
						if r.Method != http.MethodPost {
							w.WriteHeader(http.StatusNotFound)
							return
						}

						w.WriteHeader(http.StatusCreated)

						fmt.Fprintf(w, `{
							"member": {
								"id": "member_id_1",
								"name": "myPoolMember",
								"provisioning_status": "PENDING_CREATE"
							}
						}`)
					})

					Mux.HandleFunc("/v2.1/servers/f5dc173b-6804-445a-a6d8-c705dad5b5eb/metadata", func(w http.ResponseWriter, r *http.Request) {
						if r.Method != http.MethodPost {
							w.WriteHeader(http.StatusNotFound)
							return
						}

						w.WriteHeader(http.StatusOK)

						fmt.Fprintf(w, `{"meta": {}}`)
					})

					writeJsonParamToStdIn(`{
						"method": "create_vm",
						"arguments": [
							"a694d798-0b41-4255-9c8e-b282cd504a52",
							"5bba0da5-dfb3-49d8-a005-d799507518f7",
							{
								"instance_type": "m1.tiny",
								"key_name": "default_key_name",
								"availability_zones": ["z1"],
								"loadbalancer_pools": [
									{  "name": "myPool", "port": 80 }
								]
							},
							{
								"bosh": {
									"type": "manual",
									"ip": "10.0.11.16",
									"netmask": "255.255.255.0",
									"cloud_properties": {
										"availability_zone": "z1",
										"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3",
										"security_groups": [
											"0c8a5d1a-8922-4d65-a0b2-dd78ab869e04",
											"bosh_acceptance_tests"
										]
									},
									"default": [
										"dns",
										"gateway"
									],
									"gateway": "10.0.11.1"
								}
							},
							[],
							{}
						],
						"api_version": 2
					}`)

					err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
					Expect(err).ShouldNot(HaveOccurred())

					stdOutWriter.Close()
					Expect(<-outChannel).To(ContainSubstring(`"result":["f5dc173b-6804-445a-a6d8-c705dad5b5eb",{"bosh":{"type":"manual","ip":"10.0.11.16","netmask":"255.255.255.0","gateway":"10.0.11.1","dns":null,"default":["dns","gateway"],"routes":null,"cloud_properties":{"availability_zone":"z1","net_id":"fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3","security_groups":["0c8a5d1a-8922-4d65-a0b2-dd78ab869e04","bosh_acceptance_tests"]}}}],"error":null`))
				})

				It("fails if it can not retrieve load balancer pools", func() {
					writeJsonParamToStdIn(`{
						"method": "create_vm",
						"arguments": [
							"a694d798-0b41-4255-9c8e-b282cd504a52",
							"5bba0da5-dfb3-49d8-a005-d799507518f7",
							{
								"instance_type": "m1.tiny",
								"key_name": "default_key_name",
								"availability_zones": ["z1"],
								"loadbalancer_pools": [
									{  "name": "myPool", "port": 80 }
								]
							},
							{
								"bosh": {
									"type": "manual",
									"ip": "10.0.11.16",
									"netmask": "255.255.255.0",
									"cloud_properties": {
										"availability_zone": "z1",
										"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3",
										"security_groups": [
											"0c8a5d1a-8922-4d65-a0b2-dd78ab869e04",
											"bosh_acceptance_tests"
										]
									},
									"default": [
										"dns",
										"gateway"
									],
									"gateway": "10.0.11.1"
								}
							},
							[],
							{}
						],
						"api_version": 2
					}`)

					err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
					Expect(err).ShouldNot(HaveOccurred())

					stdOutWriter.Close()
					Expect(<-outChannel).To(ContainSubstring(`failed to get pool ID of pool 'myPool': failed to list loadbalancer pools`))
				})

				It("fails if it can not retrieve subnet ids", func() {
					Mux.HandleFunc("/v2.0/lbaas/pools", func(w http.ResponseWriter, r *http.Request) {
						if r.Method != http.MethodGet || r.URL.Query().Get("name") != "myPool" {
							w.WriteHeader(http.StatusNotFound)
							return
						}

						w.Header().Add("Content-Type", "application/json")
						w.WriteHeader(http.StatusOK)

						fmt.Fprintf(w, `{
							"pools": [
								{
									"id": "pool_id_1",
									"name": "myPool"
								}
							]
						}`)

					})

					writeJsonParamToStdIn(`{
						"method": "create_vm",
						"arguments": [
							"a694d798-0b41-4255-9c8e-b282cd504a52",
							"5bba0da5-dfb3-49d8-a005-d799507518f7",
							{
								"instance_type": "m1.tiny",
								"key_name": "default_key_name",
								"availability_zones": ["z1"],
								"loadbalancer_pools": [
									{  "name": "myPool", "port": 80 }
								]
							},
							{
								"bosh": {
									"type": "manual",
									"ip": "10.0.11.16",
									"netmask": "255.255.255.0",
									"cloud_properties": {
										"availability_zone": "z1",
										"net_id": "wrong-subnet-id",
										"security_groups": [
											"0c8a5d1a-8922-4d65-a0b2-dd78ab869e04",
											"bosh_acceptance_tests"
										]
									},
									"default": [
										"dns",
										"gateway"
									],
									"gateway": "10.0.11.1"
								}
							},
							[],
							{}
						],
						"api_version": 2
					}`)

					err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
					Expect(err).ShouldNot(HaveOccurred())

					stdOutWriter.Close()
					Expect(<-outChannel).To(ContainSubstring(`failed to create port: failed create network opts: failed to get subnet: failed to list subnets`))
				})

				It("fails if it can not retrieve pool", func() {
					Mux.HandleFunc("/v2.0/lbaas/pools", func(w http.ResponseWriter, r *http.Request) {
						if r.Method != http.MethodGet || r.URL.Query().Get("name") != "myPool" {
							w.WriteHeader(http.StatusNotFound)
							return
						}

						w.Header().Add("Content-Type", "application/json")
						w.WriteHeader(http.StatusOK)

						fmt.Fprintf(w, `{
							"pools": [
								{
									"id": "pool_id_1",
									"name": "myPool"
								}
							]
						}`)

					})

					writeJsonParamToStdIn(`{
						"method": "create_vm",
						"arguments": [
							"a694d798-0b41-4255-9c8e-b282cd504a52",
							"5bba0da5-dfb3-49d8-a005-d799507518f7",
							{
								"instance_type": "m1.tiny",
								"key_name": "default_key_name",
								"availability_zones": ["z1"],
								"loadbalancer_pools": [
									{  "name": "myPool", "port": 80 }
								]
							},
							{
								"bosh": {
									"type": "manual",
									"ip": "10.0.11.16",
									"netmask": "255.255.255.0",
									"cloud_properties": {
										"availability_zone": "z1",
										"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3",
										"security_groups": [
											"0c8a5d1a-8922-4d65-a0b2-dd78ab869e04",
											"bosh_acceptance_tests"
										]
									},
									"default": [
										"dns",
										"gateway"
									],
									"gateway": "10.0.11.1"
								}
							},
							[],
							{}
						],
						"api_version": 2
					}`)

					err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
					Expect(err).ShouldNot(HaveOccurred())

					stdOutWriter.Close()
					Expect(<-outChannel).To(ContainSubstring(`no load balancers or listeners associated with pool 'pool_id_1'`))
				})

				It("times out if pool does not become ACTIVE", func() {
					Mux.HandleFunc("/v2.0/lbaas/pools", func(w http.ResponseWriter, r *http.Request) {
						if r.Method != http.MethodGet || r.URL.Query().Get("name") != "myPool" {
							w.WriteHeader(http.StatusNotFound)
							return
						}

						w.Header().Add("Content-Type", "application/json")
						w.WriteHeader(http.StatusOK)

						fmt.Fprintf(w, `{
							"pools": [
								{
									"id": "pool_id_1",
									"name": "myPool",
									"loadbalancers": [{"id": "the-lb-id"}]
								}
							]
						}`)

					})

					Mux.HandleFunc("/v2.0/lbaas/loadbalancers/the-lb-id", func(w http.ResponseWriter, r *http.Request) {
						if r.Method != http.MethodGet {
							w.WriteHeader(http.StatusNotFound)
							return
						}

						w.WriteHeader(http.StatusOK)

						fmt.Fprintf(w, `{
							"loadbalancer": {
								"id": "the-lb-id",
								"provisioning_status": "PENDING_UPDATE"
							}
						}`)
					})

					writeJsonParamToStdIn(`{
						"method": "create_vm",
						"arguments": [
							"a694d798-0b41-4255-9c8e-b282cd504a52",
							"5bba0da5-dfb3-49d8-a005-d799507518f7",
							{
								"instance_type": "m1.tiny",
								"key_name": "default_key_name",
								"availability_zones": ["z1"],
								"loadbalancer_pools": [
									{  "name": "myPool", "port": 80 }
								]
							},
							{
								"bosh": {
									"type": "manual",
									"ip": "10.0.11.16",
									"netmask": "255.255.255.0",
									"cloud_properties": {
										"availability_zone": "z1",
										"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3",
										"security_groups": [
											"0c8a5d1a-8922-4d65-a0b2-dd78ab869e04",
											"bosh_acceptance_tests"
										]
									},
									"default": [
										"dns",
										"gateway"
									],
									"gateway": "10.0.11.1"
								}
							},
							[],
							{}
						],
						"api_version": 2
					}`)

					err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
					Expect(err).ShouldNot(HaveOccurred())

					stdOutWriter.Close()
					Expect(<-outChannel).To(ContainSubstring(`timeout while waiting for loadbalancer 'the-lb-id' to become active`))
				})

				It("fails if it can not set server metadata", func() {
					Mux.HandleFunc("/v2.0/lbaas/pools", func(w http.ResponseWriter, r *http.Request) {
						if r.Method != http.MethodGet || r.URL.Query().Get("name") != "myPool" {
							w.WriteHeader(http.StatusNotFound)
							return
						}

						w.Header().Add("Content-Type", "application/json")
						w.WriteHeader(http.StatusOK)

						fmt.Fprintf(w, `{
							"pools": [
								{
									"id": "pool_id_1",
									"name": "myPool",
									"loadbalancers": [{"id": "the-lb-id"}]
								}
							]
						}`)

					})

					Mux.HandleFunc("/v2.0/lbaas/loadbalancers/the-lb-id", func(w http.ResponseWriter, r *http.Request) {
						if r.Method != http.MethodGet {
							w.WriteHeader(http.StatusNotFound)
							return
						}

						w.WriteHeader(http.StatusOK)

						fmt.Fprintf(w, `{
							"loadbalancer": {
								"id": "the-lb-id",
								"provisioning_status": "ACTIVE"
							}
						}`)
					})

					Mux.HandleFunc("/v2.0/lbaas/pools/pool_id_1", func(w http.ResponseWriter, r *http.Request) {
						if r.Method != http.MethodGet {
							w.WriteHeader(http.StatusNotFound)
							return
						}

						w.WriteHeader(http.StatusOK)

						fmt.Fprintf(w, `{
							"pool": {
								"id": "pool_id_1",
								"name": "myPool",
								"provisioning_status": "ACTIVE"
							}
						}`)
					})

					Mux.HandleFunc("/v2.0/lbaas/pools/pool_id_1/members", func(w http.ResponseWriter, r *http.Request) {
						if r.Method != http.MethodPost {
							w.WriteHeader(http.StatusNotFound)
							return
						}

						w.WriteHeader(http.StatusCreated)

						fmt.Fprintf(w, `{
							"member": {
								"id": "member_id_1",
								"name": "myPoolMember",
								"provisioning_status": "PENDING_CREATE"
							}
						}`)
					})

					Mux.HandleFunc("/v2.1/servers/f5dc173b-6804-445a-a6d8-c705dad5b5eb/metadata/lbaas_pool_1", func(w http.ResponseWriter, r *http.Request) {
						if r.Method != http.MethodPut {
							w.WriteHeader(http.StatusNotFound)
							return
						}

						w.WriteHeader(http.StatusBadRequest)

						fmt.Fprintf(w, `{"meta": {}}`)
					})

					writeJsonParamToStdIn(`{
						"method": "create_vm",
						"arguments": [
							"a694d798-0b41-4255-9c8e-b282cd504a52",
							"5bba0da5-dfb3-49d8-a005-d799507518f7",
							{
								"instance_type": "m1.tiny",
								"key_name": "default_key_name",
								"availability_zones": ["z1"],
								"loadbalancer_pools": [
									{  "name": "myPool", "port": 80 }
								]
							},
							{
								"bosh": {
									"type": "manual",
									"ip": "10.0.11.16",
									"netmask": "255.255.255.0",
									"cloud_properties": {
										"availability_zone": "z1",
										"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3",
										"security_groups": [
											"0c8a5d1a-8922-4d65-a0b2-dd78ab869e04",
											"bosh_acceptance_tests"
										]
									},
									"default": [
										"dns",
										"gateway"
									],
									"gateway": "10.0.11.1"
								}
							},
							[],
							{}
						],
						"api_version": 2
					}`)

					err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
					Expect(err).ShouldNot(HaveOccurred())

					stdOutWriter.Close()
					Expect(<-outChannel).To(ContainSubstring(`failed to update metadata for server 'f5dc173b-6804-445a-a6d8-c705dad5b5eb' with error:`))
				})
			})

		})

		Context("when vm status stays BUILD", func() {
			BeforeEach(func() {
				Mux.HandleFunc("/v2.1/servers/f5dc173b-6804-445a-a6d8-c705dad5b5eb", func(w http.ResponseWriter, r *http.Request) {
					switch r.Method {
					case http.MethodGet:
						w.WriteHeader(http.StatusOK)

						fmt.Fprintf(w, `{
							"server": {
								"id": "f5dc173b-6804-445a-a6d8-c705dad5b5eb",
								"status": "BUILD"
							}
						}`)
					}
				})
			})

			It("times out when status ACTIVE is not reached", func() {
				writeJsonParamToStdIn(`{
				"method": "create_vm",
				"arguments": [
					"a694d798-0b41-4255-9c8e-b282cd504a52",
					"5bba0da5-dfb3-49d8-a005-d799507518f7",
					{
						"instance_type": "m1.tiny",
						"key_name": "default_key_name",
						"availability_zones": ["z1"]
					},
					{
						"bosh": {
							"type": "manual",
							"ip": "10.0.11.16",
							"netmask": "255.255.255.0",
							"cloud_properties": {
								"availability_zone": "z1",
								"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3",
								"security_groups": [
									"0c8a5d1a-8922-4d65-a0b2-dd78ab869e04",
									"bosh_acceptance_tests"
								]
							},
							"default": [
								"dns",
								"gateway"
							],
							"gateway": "10.0.11.1"
						}
					},
					[],
					{}
				],
				"api_version": 2
			}`)

				defaultConfig = getDefaultConfig(Endpoint())
				defaultConfig.Cloud.Properties.Openstack.StateTimeOut = 1

				err := cpi.Execute(defaultConfig, logger)
				Expect(err).ShouldNot(HaveOccurred())

				stdOutWriter.Close()
				Expect(<-outChannel).To(ContainSubstring(`timeout while waiting for server to become active`))
			})
		})

		Context("when vm status goes to ERROR", func() {
			BeforeEach(func() {
				Mux.HandleFunc("/v2.1/servers/f5dc173b-6804-445a-a6d8-c705dad5b5eb", func(w http.ResponseWriter, r *http.Request) {
					switch r.Method {
					case http.MethodGet:
						w.WriteHeader(http.StatusOK)

						fmt.Fprintf(w, `{
							"server": {
								"id": "f5dc173b-6804-445a-a6d8-c705dad5b5eb",
								"status": "ERROR"
							}
						}`)
					}
				})
			})

			It("fails if server status became ERROR", func() {
				writeJsonParamToStdIn(`{
				"method": "create_vm",
				"arguments": [
					"a694d798-0b41-4255-9c8e-b282cd504a52",
					"5bba0da5-dfb3-49d8-a005-d799507518f7",
					{
						"instance_type": "m1.tiny",
						"key_name": "default_key_name",
						"availability_zones": ["z1"]
					},
					{
						"bosh": {
							"type": "manual",
							"ip": "10.0.11.16",
							"netmask": "255.255.255.0",
							"cloud_properties": {
								"availability_zone": "z1",
								"net_id": "fbe64fb7-b47c-4fd1-b158-9411d5c3ebf3",
								"security_groups": [
									"0c8a5d1a-8922-4d65-a0b2-dd78ab869e04",
									"bosh_acceptance_tests"
								]
							},
							"default": [
								"dns",
								"gateway"
							],
							"gateway": "10.0.11.1"
						}
					},
					[],
					{}
				],
				"api_version": 2
			}`)

				defaultConfig = getDefaultConfig(Endpoint())
				defaultConfig.Cloud.Properties.Openstack.StateTimeOut = 1

				err := cpi.Execute(defaultConfig, logger)
				Expect(err).ShouldNot(HaveOccurred())

				stdOutWriter.Close()
				Expect(<-outChannel).To(ContainSubstring(`server became ERROR state while waiting to become ACTIVE`))
			})
		})
	})

})
