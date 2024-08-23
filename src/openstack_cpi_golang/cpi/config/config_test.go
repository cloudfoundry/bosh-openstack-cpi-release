package config_test

import (
	"testing/fstest"

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

				Expect(err.Error()).To(ContainSubstring("Invalid OpenStack cloud properties: username and api_key or application_credential_id and application_credential_secret is required"))
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

				Expect(err.Error()).To(ContainSubstring("Invalid OpenStack cloud properties: config_drive must be either 'cdrom' or 'disk'"))
			})

			It("returns an error if config is empty", func() {
				_, err := config.NewConfigFromPath(fileSystem, "some/path/empty_config.json")

				Expect(err.Error()).To(ContainSubstring("Invalid OpenStack cloud properties: username and api_key or application_credential_id and application_credential_secret is required"))
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
})
