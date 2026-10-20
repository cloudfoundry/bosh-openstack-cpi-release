package config_test

import (
	"testing/fstest"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("OpenstackConfig", func() {
	var fileSystem fstest.MapFS

	BeforeEach(func() {
		fileSystem = fstest.MapFS{
			"some/path/config.json": &fstest.MapFile{
				Data: []byte(`{
						"cloud": {
							"properties": {
								"openstack": {
									"auth_url": "the_auth_url",
									"username": "the_username",
									"api_key": "the_api_key",
									"domain": "the_domain",
									"tenant": "the_tenant",
									"region": "the_region",
									"default_key_name": "the_default_key_name",
									"stemcell_public_visibility": true
								}
							}
						}
					}`),
			},
			"some/path/config.txt": &fstest.MapFile{
				Data: []byte(`not a json file`),
			},
			"some/path/invalid_user_config.json": &fstest.MapFile{
				Data: []byte(`{
						"cloud": {
							"properties": {
								"openstack": {	
									"username": "the_username",
									"application_credential_id": "the_application_credential_id"
								}
							}
						}
					}`),
			},
			"some/path/invalid_config_drive.json": &fstest.MapFile{
				Data: []byte(`{
						"cloud": {
							"properties": {
								"openstack": {
									"application_credential_id": "the_application_credential_id",
									"application_credential_secret": "the_application_credential_secret",
									"config_drive": "not_cdrom_or_disk"
								}
							}
						}
					}`),
			},
			"some/path/disk_config_drive.json": &fstest.MapFile{
				Data: []byte(`{
						"cloud": {
							"properties": {
								"openstack": {
									"application_credential_id": "the_application_credential_id",
									"application_credential_secret": "the_application_credential_secret",
									"config_drive": "disk"
								}
							}
						}
					}`),
			},
			"some/path/cdrom_config_drive.json": &fstest.MapFile{
				Data: []byte(`{
						"cloud": {
							"properties": {
								"openstack": {
									"application_credential_id": "the_application_credential_id",
									"application_credential_secret": "the_application_credential_secret",
									"config_drive": "cdrom"
								}
							}
						}
					}`),
			},
			"some/path/empty_config.json": &fstest.MapFile{
				Data: []byte(`{
						"cloud": {
							"properties": {
								"openstack": {}
							}
						}
					}`),
			},
			"some/path/username_api_key_config.json": &fstest.MapFile{
				Data: []byte(`{
						"cloud": {
							"properties": {
								"openstack": {
									"auth_url": "the_auth_url",
									"username": "the_username",
									"api_key": "the_api_key",
									"domain": "the_domain",
									"project": "the_project"	
								}
							}
						}
					}`),
			},
			"some/path/application_credential_config.json": &fstest.MapFile{
				Data: []byte(`{
						"cloud": {
							"properties": {
								"openstack": {
									"auth_url": "the_auth_url",
									"application_credential_id": "the_application_credential_id",
									"application_credential_secret": "the_application_credential_secret"
								}
							}
						}
					}`),
			},
			"some/path/config_without_retry_config.json": &fstest.MapFile{
				Data: []byte(`{
						"cloud": {
							"properties": {
								"openstack": {
									"auth_url": "the_auth_url",
									"application_credential_id": "the_application_credential_id",
									"application_credential_secret": "the_application_credential_secret"
								}
							}
						}
					}`),
			},
			"some/path/config_with_retry_configs.json": &fstest.MapFile{
				Data: []byte(`{
						"cloud": {
							"properties": {
								"openstack": {
									"auth_url": "the_auth_url",
									"application_credential_id": "the_application_credential_id",
									"application_credential_secret": "the_application_credential_secret"
								},
								"retry_config": {	
									"default": {
										"sleep_duration": 5,
										"max_attempts": 20
									},
									"create_server": {
										"sleep_duration": 10,
										"max_attempts": 30
									}
								}
							}
						}
					}`),
			},
		}
	})

	Context("NewConfigFromPath", func() {
		It("gets the cpi configuration from filesystem", func() {
			cpiConfig, err := config.NewConfigFromPath(fileSystem, "some/path/config.json")

			Expect(err).ToNot(HaveOccurred())
			Expect(cpiConfig.Cloud.Properties.Openstack.AuthURL).To(Equal("the_auth_url"))
			Expect(cpiConfig.Cloud.Properties.Openstack.Username).To(Equal("the_username"))
			Expect(cpiConfig.Cloud.Properties.Openstack.APIKey).To(Equal("the_api_key"))
			Expect(cpiConfig.Cloud.Properties.Openstack.DomainName).To(Equal("the_domain"))
			Expect(cpiConfig.Cloud.Properties.Openstack.Tenant).To(Equal("the_tenant"))
			Expect(cpiConfig.Cloud.Properties.Openstack.Region).To(Equal("the_region"))
			Expect(cpiConfig.Cloud.Properties.Openstack.DefaultKeyName).To(Equal("the_default_key_name"))
			Expect(cpiConfig.Cloud.Properties.Openstack.StemcellPubliclyVisible).To(BeTrue())
		})

		It("returns an error if config file cannot be found", func() {
			_, err := config.NewConfigFromPath(fileSystem, "some/path/not_existing_config.json")

			Expect(err.Error()).To(ContainSubstring("failed to open configuration file: open some/path/not_existing_config.json: file does not exist"))
		})

		It("returns an error if config file cannot be found", func() {
			_, err := config.NewConfigFromPath(fileSystem, "some/path")

			Expect(err.Error()).To(Equal("failed to read configuration file: read some/path: invalid argument"))
		})

		It("returns an error if config file json cannot be unmarshalled", func() {
			_, err := config.NewConfigFromPath(fileSystem, "some/path/config.txt")

			Expect(err.Error()).To(ContainSubstring("failed to unmarshall configuration file: some/path/config.txt, err: invalid character"))
		})

	})

	Context("Validate", func() {
		Context("OpenstackConfig", func() {
			It("returns an error if username and application credential is set", func() {
				_, err := config.NewConfigFromPath(fileSystem, "some/path/invalid_user_config.json")

				Expect(err.Error()).To(ContainSubstring("invalid OpenStack cloud properties: username and api_key or application_credential_id and application_credential_secret is required"))
			})

			It("config drive can be set to disk", func() {
				cpiConfig, err := config.NewConfigFromPath(fileSystem, "some/path/disk_config_drive.json")

				Expect(err).ToNot(HaveOccurred())
				Expect(cpiConfig.Cloud.Properties.Openstack.ConfigDrive).To(Equal("disk"))
			})

			It("config drive can be set to cdrom", func() {
				cpiConfig, err := config.NewConfigFromPath(fileSystem, "some/path/cdrom_config_drive.json")

				Expect(err).ToNot(HaveOccurred())
				Expect(cpiConfig.Cloud.Properties.Openstack.ConfigDrive).To(Equal("cdrom"))
			})

			It("returns an error if config drive is invalid", func() {
				_, err := config.NewConfigFromPath(fileSystem, "some/path/invalid_config_drive.json")

				Expect(err.Error()).To(ContainSubstring("invalid OpenStack cloud properties: config_drive must be either 'cdrom' or 'disk'"))
			})

			It("returns an error if config is empty", func() {
				_, err := config.NewConfigFromPath(fileSystem, "some/path/empty_config.json")

				Expect(err.Error()).To(ContainSubstring("invalid OpenStack cloud properties: username and api_key or application_credential_id and application_credential_secret is required"))
			})

			It("succeeds with username and api_key", func() {
				cpiConfig, err := config.NewConfigFromPath(fileSystem, "some/path/username_api_key_config.json")

				Expect(err).ToNot(HaveOccurred())
				Expect(cpiConfig.Cloud.Properties.Openstack.Username).To(Equal("the_username"))
				Expect(cpiConfig.Cloud.Properties.Openstack.APIKey).To(Equal("the_api_key"))
			})

			It("succeeds with application credential id and secret", func() {
				cpiConfig, err := config.NewConfigFromPath(fileSystem, "some/path/application_credential_config.json")

				Expect(err).ToNot(HaveOccurred())
				Expect(cpiConfig.Cloud.Properties.Openstack.ApplicationCredentialID).To(Equal("the_application_credential_id"))
				Expect(cpiConfig.Cloud.Properties.Openstack.ApplicationCredentialSecret).To(Equal("the_application_credential_secret"))
			})
		})

		Context("Properties", func() {
			It("has a default retry configurations ", func() {
				cpiConfig, err := config.NewConfigFromPath(fileSystem, "some/path/config_without_retry_config.json")

				Expect(err).ToNot(HaveOccurred())
				Expect(cpiConfig.Properties().RetryConfig.Default().SleepDuration).To(Equal(3))
				Expect(cpiConfig.Properties().RetryConfig.Default().MaxAttempts).To(Equal(10))
			})

			It("supports overwriting the default retry configurations", func() {
				cpiConfig, err := config.NewConfigFromPath(fileSystem, "some/path/config_with_retry_configs.json")

				Expect(err).ToNot(HaveOccurred())
				Expect(cpiConfig.Properties().RetryConfig.Default().SleepDuration).To(Equal(5))
				Expect(cpiConfig.Properties().RetryConfig.Default().MaxAttempts).To(Equal(20))
				Expect(cpiConfig.Properties().RetryConfig["default"].SleepDuration).To(Equal(5))
				Expect(cpiConfig.Properties().RetryConfig["default"].MaxAttempts).To(Equal(20))
				Expect(cpiConfig.Properties().RetryConfig["create_server"].SleepDuration).To(Equal(10))
				Expect(cpiConfig.Properties().RetryConfig["create_server"].MaxAttempts).To(Equal(30))
			})

			It("supports setting multiple retry configurations", func() {
				cpiConfig, err := config.NewConfigFromPath(fileSystem, "some/path/application_credential_config.json")

				Expect(err).ToNot(HaveOccurred())
				Expect(cpiConfig.Cloud.Properties.Openstack.ApplicationCredentialID).To(Equal("the_application_credential_id"))
				Expect(cpiConfig.Cloud.Properties.Openstack.ApplicationCredentialSecret).To(Equal("the_application_credential_secret"))
			})
		})
	})

	Context("AuthOptions", func() {
		It("configures AuthOptions with username and password", func() {
			cpiConfig, err := config.NewConfigFromPath(fileSystem, "some/path/username_api_key_config.json")

			Expect(err).ToNot(HaveOccurred())
			Expect(cpiConfig.Cloud.Properties.Openstack.AuthOptions().IdentityEndpoint).To(Equal("the_auth_url"))
			Expect(cpiConfig.Cloud.Properties.Openstack.AuthOptions().Username).To(Equal("the_username"))
			Expect(cpiConfig.Cloud.Properties.Openstack.AuthOptions().Password).To(Equal("the_api_key"))
			Expect(cpiConfig.Cloud.Properties.Openstack.AuthOptions().DomainName).To(Equal("the_domain"))
			Expect(cpiConfig.Cloud.Properties.Openstack.AuthOptions().TenantName).To(Equal("the_project"))
		})

		It("configures AuthOptions with application credential id and secret", func() {
			cpiConfig, err := config.NewConfigFromPath(fileSystem, "some/path/application_credential_config.json")

			Expect(err).ToNot(HaveOccurred())
			Expect(cpiConfig.Cloud.Properties.Openstack.AuthOptions().IdentityEndpoint).To(Equal("the_auth_url"))
			Expect(cpiConfig.Cloud.Properties.Openstack.AuthOptions().ApplicationCredentialID).To(Equal("the_application_credential_id"))
			Expect(cpiConfig.Cloud.Properties.Openstack.AuthOptions().ApplicationCredentialSecret).To(Equal("the_application_credential_secret"))
		})
	})
	Context("MergeContext", func() {
		var openstackConfig config.OpenstackConfig

		BeforeEach(func() {
			openstackConfig = config.OpenstackConfig{
				AuthURL:               "the_static_auth_url",
				Username:              "the_static_username",
				APIKey:                "the_static_api_key",
				Region:                "the_static_region",
				DomainName:            "the_static_domain",
				ProjectName:           "the_static_project",
				DefaultKeyName:        "the_static_default_key_name",
				DefaultSecurityGroups: []string{"the_static_security_group"},
			}
		})

		It("overrides only the fields present in the call context, as a multi-CPI director would send them", func() {
			ctx := apiv1.CloudPropsImpl{RawMessage: []byte(`{
				"director_uuid": "some-director-uuid",
				"request_id": "cpi-123",
				"auth_url": "https://osvip-po-c01.example.com:5000/v3/auth",
				"region": "PO-C",
				"default_security_groups": ["some-po-c-security-group"]
			}`)}

			merged, err := openstackConfig.MergeContext(ctx)

			Expect(err).ToNot(HaveOccurred())
			Expect(merged.AuthURL).To(Equal("https://osvip-po-c01.example.com:5000/v3/auth"))
			Expect(merged.Region).To(Equal("PO-C"))
			Expect(merged.DefaultSecurityGroups).To(Equal([]string{"some-po-c-security-group"}))

			// fields absent from the context are left untouched
			Expect(merged.Username).To(Equal("the_static_username"))
			Expect(merged.APIKey).To(Equal("the_static_api_key"))
			Expect(merged.DomainName).To(Equal("the_static_domain"))
			Expect(merged.ProjectName).To(Equal("the_static_project"))
			Expect(merged.DefaultKeyName).To(Equal("the_static_default_key_name"))
		})

		It("clears application credentials when the context switches to username/api_key auth", func() {
			appCredConfig := config.OpenstackConfig{
				AuthURL:                     "the_static_auth_url",
				ApplicationCredentialID:     "the_static_app_cred_id",
				ApplicationCredentialSecret: "the_static_app_cred_secret",
				Region:                      "the_static_region",
			}

			ctx := apiv1.CloudPropsImpl{RawMessage: []byte(`{
				"username": "the_context_username",
				"api_key": "the_context_api_key"
			}`)}

			merged, err := appCredConfig.MergeContext(ctx)

			Expect(err).ToNot(HaveOccurred())
			Expect(merged.Username).To(Equal("the_context_username"))
			Expect(merged.APIKey).To(Equal("the_context_api_key"))
			// the opposite credential pair must be cleared
			Expect(merged.ApplicationCredentialID).To(BeEmpty())
			Expect(merged.ApplicationCredentialSecret).To(BeEmpty())
			// the merged config must be valid (exactly one credential form)
			Expect(merged.Validate()).ToNot(HaveOccurred())
		})

		It("clears username/api_key when the context switches to application credential auth", func() {
			usernameConfig := config.OpenstackConfig{
				AuthURL:  "the_static_auth_url",
				Username: "the_static_username",
				APIKey:   "the_static_api_key",
				Region:   "the_static_region",
			}

			ctx := apiv1.CloudPropsImpl{RawMessage: []byte(`{
				"application_credential_id": "the_context_app_cred_id",
				"application_credential_secret": "the_context_app_cred_secret"
			}`)}

			merged, err := usernameConfig.MergeContext(ctx)

			Expect(err).ToNot(HaveOccurred())
			Expect(merged.ApplicationCredentialID).To(Equal("the_context_app_cred_id"))
			Expect(merged.ApplicationCredentialSecret).To(Equal("the_context_app_cred_secret"))
			// the opposite credential pair must be cleared
			Expect(merged.Username).To(BeEmpty())
			Expect(merged.APIKey).To(BeEmpty())
			// the merged config must be valid (exactly one credential form)
			Expect(merged.Validate()).ToNot(HaveOccurred())
		})

		It("does not clear working credentials when the context carries null/empty credential fields", func() {
			usernameConfig := config.OpenstackConfig{
				AuthURL:  "the_static_auth_url",
				Username: "the_static_username",
				APIKey:   "the_static_api_key",
				Region:   "the_static_region",
			}

			// A context that mentions the opposite credential pair as null or
			// empty must NOT be treated as a credential switch.
			ctx := apiv1.CloudPropsImpl{RawMessage: []byte(`{
				"region": "PO-C",
				"application_credential_id": null,
				"application_credential_secret": ""
			}`)}

			merged, err := usernameConfig.MergeContext(ctx)

			Expect(err).ToNot(HaveOccurred())
			// static username/api_key must be preserved
			Expect(merged.Username).To(Equal("the_static_username"))
			Expect(merged.APIKey).To(Equal("the_static_api_key"))
			Expect(merged.Region).To(Equal("PO-C"))
			Expect(merged.Validate()).ToNot(HaveOccurred())
		})

		It("does not clear working application credentials when the context carries null/empty username/api_key", func() {
			appCredConfig := config.OpenstackConfig{
				AuthURL:                     "the_static_auth_url",
				ApplicationCredentialID:     "the_static_app_cred_id",
				ApplicationCredentialSecret: "the_static_app_cred_secret",
				Region:                      "the_static_region",
			}

			ctx := apiv1.CloudPropsImpl{RawMessage: []byte(`{
				"region": "PO-C",
				"username": null,
				"api_key": ""
			}`)}

			merged, err := appCredConfig.MergeContext(ctx)

			Expect(err).ToNot(HaveOccurred())
			// static application credentials must be preserved
			Expect(merged.ApplicationCredentialID).To(Equal("the_static_app_cred_id"))
			Expect(merged.ApplicationCredentialSecret).To(Equal("the_static_app_cred_secret"))
			Expect(merged.Region).To(Equal("PO-C"))
			Expect(merged.Validate()).ToNot(HaveOccurred())
		})

		It("does not let a null/empty context value overwrite a credential of the same pair", func() {
			usernameConfig := config.OpenstackConfig{
				AuthURL:  "the_static_auth_url",
				Username: "the_static_username",
				APIKey:   "the_static_api_key",
				Region:   "the_static_region",
			}

			// Context supplies api_key as null for the SAME pair the static
			// config uses; it must not clobber the working api_key.
			ctx := apiv1.CloudPropsImpl{RawMessage: []byte(`{
				"region": "PO-C",
				"api_key": null
			}`)}

			merged, err := usernameConfig.MergeContext(ctx)

			Expect(err).ToNot(HaveOccurred())
			Expect(merged.Username).To(Equal("the_static_username"))
			Expect(merged.APIKey).To(Equal("the_static_api_key"))
			Expect(merged.Region).To(Equal("PO-C"))
			Expect(merged.Validate()).ToNot(HaveOccurred())
		})

		It("rejects a non-string credential value in the context instead of discarding it", func() {
			usernameConfig := config.OpenstackConfig{
				AuthURL:  "the_static_auth_url",
				Username: "the_static_username",
				APIKey:   "the_static_api_key",
				Region:   "the_static_region",
			}

			// A malformed (numeric) credential override must fail loudly, not be
			// silently dropped (which could reuse static creds on a new endpoint).
			ctx := apiv1.CloudPropsImpl{RawMessage: []byte(`{
				"auth_url": "https://osvip-po-c01.example.com:5000/v3/auth",
				"api_key": 12345
			}`)}

			_, err := usernameConfig.MergeContext(ctx)

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("credential field \"api_key\" must be a string"))
		})

		It("returns the unmodified config when the context carries no OpenStack overrides", func() {
			ctx := apiv1.CloudPropsImpl{RawMessage: []byte(`{
				"director_uuid": "some-director-uuid",
				"request_id": "cpi-123"
			}`)}

			merged, err := openstackConfig.MergeContext(ctx)

			Expect(err).ToNot(HaveOccurred())
			Expect(merged).To(Equal(openstackConfig))
		})

		It("also picks up the stemcell API version every call context carries, since OpenstackConfig.VM mirrors it", func() {
			ctx := apiv1.CloudPropsImpl{RawMessage: []byte(`{
				"director_uuid": "some-director-uuid",
				"request_id": "cpi-123",
				"vm": {"stemcell": {"api_version": 3}}
			}`)}

			merged, err := openstackConfig.MergeContext(ctx)

			Expect(err).ToNot(HaveOccurred())
			Expect(merged.VM.Stemcell.APIVersion).To(Equal(3))
		})

		It("returns the unmodified config for an empty context object", func() {
			ctx := apiv1.CloudPropsImpl{RawMessage: []byte(`{}`)}

			merged, err := openstackConfig.MergeContext(ctx)

			Expect(err).ToNot(HaveOccurred())
			Expect(merged).To(Equal(openstackConfig))
		})

		It("returns the unmodified config when no context is provided (single-CPI director)", func() {
			ctx := apiv1.CloudPropsImpl{}

			merged, err := openstackConfig.MergeContext(ctx)

			Expect(err).ToNot(HaveOccurred())
			Expect(merged).To(Equal(openstackConfig))
		})

		It("rejects a whitespace-only context payload as malformed", func() {
			ctx := apiv1.CloudPropsImpl{RawMessage: []byte("   ")}

			_, err := openstackConfig.MergeContext(ctx)

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("failed to parse CPI call context"))
		})

		It("errors when the context cannot be parsed", func() {
			ctx := apiv1.CloudPropsImpl{RawMessage: []byte(`not-json`)}

			_, err := openstackConfig.MergeContext(ctx)

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("failed to parse CPI call context"))
		})
	})
})
