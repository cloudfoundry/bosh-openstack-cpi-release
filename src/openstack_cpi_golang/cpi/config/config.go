package config

import (
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"strings"

	"github.com/gophercloud/gophercloud"
)

type CpiConfig struct {
	Cloud struct {
		Properties Properties `json:"properties"`
	} `json:"cloud"`
}

func (c CpiConfig) OpenStackConfig() OpenstackConfig {
	return c.Cloud.Properties.Openstack
}

func (c CpiConfig) Properties() Properties {
	return c.Cloud.Properties
}

type Properties struct {
	Openstack   OpenstackConfig `json:"openstack"`
	Agent       Agent           `json:"agent"`
	RetryConfig RetryConfigMap  `json:"retry_config,omitempty"`
}

type OpenstackConfig struct {
	AuthURL                      string   `json:"auth_url"`
	Username                     string   `json:"username"`
	APIKey                       string   `json:"api_key"`
	ApplicationCredentialID      string   `json:"application_credential_id"`
	ApplicationCredentialSecret  string   `json:"application_credential_secret"`
	Region                       string   `json:"region"`
	EndpointType                 string   `json:"endpoint_type"`
	DefaultKeyName               string   `json:"default_key_name"`
	DefaultSecurityGroups        []string `json:"default_security_groups"`
	DefaultVolumeType            string   `json:"default_volume_type"`
	WaitResourcePollInterval     int      `json:"wait_resource_poll_interval"`
	BootFromVolume               bool     `json:"boot_from_volume"`
	ConfigDrive                  string   `json:"config_drive"`
	UseDHCP                      bool     `json:"use_dhcp"`
	IgnoreServerAvailabilityZone bool     `json:"ignore_server_availability_zone"`
	HumanReadableVMNames         bool     `json:"human_readable_vm_names"`
	UseNovaNetworking            bool     `json:"use_nova_networking"`
	ConnectionOptions            string   `json:"connection_options"`
	DomainName                   string   `json:"domain"`
	ProjectName                  string   `json:"project"`
	Tenant                       string   `json:"tenant"`
	StateTimeOut                 int      `json:"state_timeout"`
	StemcellPubliclyVisible      bool     `json:"stemcell_public_visibility"`
	VM                           struct {
		Stemcell struct {
			APIVersion int `json:"api_version"`
		} `json:"stemcell"`
	} `json:"vm"`
}

type RetryConfigMap map[string]RetryConfig

func (r RetryConfigMap) Default() RetryConfig {
	if config, ok := r["default"]; ok {
		return config
	}

	return RetryConfig{
		MaxAttempts:   10,
		SleepDuration: 3,
	}
}

type RetryConfig struct {
	MaxAttempts   int `json:"max_attempts"`
	SleepDuration int `json:"sleep_duration"`
}

type Agent struct {
	MBus string `json:"mbus"`
}

func (cpiConfig CpiConfig) Validate() error {
	err := cpiConfig.Cloud.Properties.Validate()
	if err != nil {
		return fmt.Errorf("failed to validate the cpi configuration: %w", err)
	}

	return nil
}

func (p Properties) Validate() error {
	err := p.Openstack.Validate()
	if err != nil {
		return fmt.Errorf("failed to validate the properties configuration: %w", err)
	}

	return nil
}

func (o OpenstackConfig) Validate() error {
	if !((o.usernameIsSet() && !o.applicationCredentialIsSet()) ||
		(!o.usernameIsSet() && o.applicationCredentialIsSet())) {
		return fmt.Errorf("'Invalid OpenStack cloud properties: username and api_key or application_credential_id and application_credential_secret is required'")
	}

	if o.ConfigDrive != "" && o.ConfigDrive != "cdrom" && o.ConfigDrive != "disk" {
		return fmt.Errorf("Invalid OpenStack cloud properties: config_drive must be either 'cdrom' or 'disk'")
	}

	return nil
}

func (o OpenstackConfig) AuthOptions() gophercloud.AuthOptions {
	if o.usernameIsSet() {
		return gophercloud.AuthOptions{
			IdentityEndpoint: o.AuthURL,
			Username:         o.Username,
			Password:         o.APIKey,
			DomainName:       o.DomainName,
			TenantName:       o.ProjectName,
		}
	} else {
		return gophercloud.AuthOptions{
			IdentityEndpoint:            o.AuthURL,
			ApplicationCredentialID:     o.ApplicationCredentialID,
			ApplicationCredentialSecret: o.ApplicationCredentialSecret,
		}
	}
}

func (o OpenstackConfig) usernameIsSet() bool {
	return o.Username != "" && o.APIKey != ""
}

func (o OpenstackConfig) applicationCredentialIsSet() bool {
	return o.ApplicationCredentialID != "" && o.ApplicationCredentialSecret != ""
}

func NewConfigFromPath(filesystem fs.FS, path string) (CpiConfig, error) {
	var config CpiConfig

	file, err := filesystem.Open(strings.TrimPrefix(path, "/"))
	if err != nil {
		return config, fmt.Errorf("failed to open configuration file: %w", err)
	}
	defer file.Close()

	data, err := io.ReadAll(file)
	if err != nil {
		return config, fmt.Errorf("failed to read configuration file: %w", err)
	}

	err = json.Unmarshal(data, &config)
	if err != nil {
		return config, fmt.Errorf("failed to unmarshall configuration file: %s, err: %w", path, err)
	}

	err = config.Validate()
	if err != nil {
		return config, fmt.Errorf("failed to validate configuration file: %s, err: %w", path, err)
	}

	return config, nil
}
