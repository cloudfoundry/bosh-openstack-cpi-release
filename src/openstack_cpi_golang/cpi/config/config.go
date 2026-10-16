package config

import (
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"strings"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
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

// MergeContext overlays OpenStack-related fields found in a CPI call context on
// top of this configuration. A director with a multi-CPI (CPI config) setup
// sends the per-CPI "properties" block (auth_url, region, credentials, etc.) as
// the JSON-RPC request context, so that a single installed CPI job can serve
// several OpenStack endpoints. Only fields present in the context override the
// job's static configuration; everything else is left untouched. This mirrors
// the legacy Ruby CPI's `cloud_properties['openstack'].merge!(context)` behavior.
//
// Validation of the merged configuration is the caller's responsibility
// (Factory.New), since validation must happen after merging regardless of
// whether the context is present or empty.
func (o OpenstackConfig) MergeContext(ctx apiv1.CallContext) (OpenstackConfig, error) {
	// The CPI call context is optional. Single-CPI directors (and several
	// dispatcher/test paths) issue requests without one; the dispatcher then
	// leaves the raw context payload empty. Only a truly absent (empty) payload
	// is treated as "no overrides"; otherwise CallContext.As would fail on the
	// empty payload ("unexpected end of JSON input") and break every call that
	// does not carry a context. A present payload (including a malformed or
	// whitespace-only one) is still parsed and rejected below.
	if cp, ok := ctx.(apiv1.CloudPropsImpl); ok && len(cp.RawMessage) == 0 {
		return o, nil
	}

	var contextFields map[string]json.RawMessage
	if err := ctx.As(&contextFields); err != nil {
		return o, fmt.Errorf("failed to parse CPI call context: %w", err)
	}

	if len(contextFields) == 0 {
		return o, nil
	}

	baseJSON, err := json.Marshal(o)
	if err != nil {
		return o, fmt.Errorf("failed to marshal openstack configuration: %w", err)
	}

	var merged map[string]json.RawMessage
	if err := json.Unmarshal(baseJSON, &merged); err != nil {
		return o, fmt.Errorf("failed to unmarshal openstack configuration: %w", err)
	}

	// Credentials come in two mutually exclusive forms: username/api_key or
	// application_credential_id/application_credential_secret. When the context
	// switches to one form, remove the other from the base config so the merged
	// result does not carry both. Validate() rejects configs with both forms,
	// and AuthOptions() would otherwise mis-resolve (it prefers username/api_key
	// whenever present). This must happen before applying the context overrides.
	_, ctxHasUsername := contextFields["username"]
	_, ctxHasAPIKey := contextFields["api_key"]
	_, ctxHasAppCredID := contextFields["application_credential_id"]
	_, ctxHasAppCredSecret := contextFields["application_credential_secret"]

	if ctxHasUsername || ctxHasAPIKey {
		delete(merged, "application_credential_id")
		delete(merged, "application_credential_secret")
	}
	if ctxHasAppCredID || ctxHasAppCredSecret {
		delete(merged, "username")
		delete(merged, "api_key")
	}

	for key, value := range contextFields {
		merged[key] = value
	}

	mergedJSON, err := json.Marshal(merged)
	if err != nil {
		return o, fmt.Errorf("failed to marshal merged openstack configuration: %w", err)
	}

	var result OpenstackConfig
	if err := json.Unmarshal(mergedJSON, &result); err != nil {
		return o, fmt.Errorf("failed to unmarshal merged openstack configuration: %w", err)
	}

	return result, nil
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
	AuthURL                      string         `json:"auth_url"`
	Username                     string         `json:"username"`
	APIKey                       string         `json:"api_key"`
	ApplicationCredentialID      string         `json:"application_credential_id"`
	ApplicationCredentialSecret  string         `json:"application_credential_secret"`
	Region                       string         `json:"region"`
	EndpointType                 string         `json:"endpoint_type"`
	DefaultKeyName               string         `json:"default_key_name"`
	DefaultSecurityGroups        []string       `json:"default_security_groups"`
	DefaultVolumeType            string         `json:"default_volume_type"`
	WaitResourcePollInterval     int            `json:"wait_resource_poll_interval"`
	BootFromVolume               bool           `json:"boot_from_volume"`
	ConfigDrive                  string         `json:"config_drive"`
	UseDHCP                      bool           `json:"use_dhcp"`
	IgnoreServerAvailabilityZone bool           `json:"ignore_server_availability_zone"`
	HumanReadableVMNames         bool           `json:"human_readable_vm_names"`
	UseNovaNetworking            bool           `json:"use_nova_networking"`
	ConnectionOptions            map[string]any `json:"connection_options"`
	DomainName                   string         `json:"domain"`
	ProjectName                  string         `json:"project"`
	Tenant                       string         `json:"tenant"`
	StateTimeOut                 int            `json:"state_timeout"`
	StemcellPubliclyVisible      bool           `json:"stemcell_public_visibility"`
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
	if !((o.usernameIsSet() && !o.applicationCredentialIsSet()) || //nolint:staticcheck
		(!o.usernameIsSet() && o.applicationCredentialIsSet())) {
		return fmt.Errorf("'invalid OpenStack cloud properties: username and api_key or application_credential_id and application_credential_secret is required'")
	}

	if o.ConfigDrive != "" && o.ConfigDrive != "cdrom" && o.ConfigDrive != "disk" {
		return fmt.Errorf("invalid OpenStack cloud properties: config_drive must be either 'cdrom' or 'disk'")
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
	defer file.Close() //nolint:errcheck

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
