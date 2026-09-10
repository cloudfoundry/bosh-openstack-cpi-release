package helpers

import (
	"fmt"
	"os"

	yaml "gopkg.in/yaml.v3"
)

// Config holds everything the BATs need at runtime.
type Config struct {
	// BOSH director connection
	Director     string
	Client       string
	ClientSecret string
	CACert       string
	AllProxy     string

	// Stemcell tarball path on disk (Concourse input)
	StemcellPath string

	// Parsed from BAT_DEPLOYMENT_SPEC
	BATs BATProperties
}

// BATProperties mirrors the relevant subset of the bats-config.yml schema
// written by run-bats.sh.
type BATProperties struct {
	InstanceType            string      `yaml:"instance_type"`
	FlavorWithNoEphemeralDisk string    `yaml:"flavor_with_no_ephemeral_disk"`
	VIP                     string      `yaml:"vip"`
	SecondStaticIP          string      `yaml:"second_static_ip"`
	AvailabilityZone        string      `yaml:"availability_zone"`
	Stemcell                StemcellRef `yaml:"stemcell"`
	SSHGateway              SSHGateway  `yaml:"ssh_gateway"`
	SSHKeyPair              SSHKeyPair  `yaml:"ssh_key_pair"`
	Networks                []Network   `yaml:"networks"`
}

// StemcellRef is the stemcell stanza in bats-config.yml.
type StemcellRef struct {
	Name    string `yaml:"name"`
	Version string `yaml:"version"`
}

// SSHGateway describes the jumpbox used for BOSH SSH tunnels.
type SSHGateway struct {
	Host     string `yaml:"host"`
	Username string `yaml:"username"`
}

// SSHKeyPair holds the jumpbox key pair for SSH tunnel establishment.
type SSHKeyPair struct {
	PublicKey  string `yaml:"public_key"`
	PrivateKey string `yaml:"private_key"`
}

// Network is one entry in the bats-config.yml networks list.
type Network struct {
	Name       string             `yaml:"name"`
	StaticIP   string             `yaml:"static_ip"`
	Type       string             `yaml:"type"`
	CloudProps NetworkCloudProps  `yaml:"cloud_properties"`
	CIDR       string             `yaml:"cidr"`
	Reserved   []string           `yaml:"reserved"`
	Static     []string           `yaml:"static"`
	Gateway    string             `yaml:"gateway"`
}

// NetworkCloudProps mirrors the OpenStack cloud_properties for a network.
type NetworkCloudProps struct {
	NetID          string   `yaml:"net_id"`
	SecurityGroups []string `yaml:"security_groups"`
}

type batsConfigFile struct {
	CPI        string        `yaml:"cpi"`
	Properties BATProperties `yaml:"properties"`
}

// NewConfig reads all required env vars and the BAT_DEPLOYMENT_SPEC file.
func NewConfig() (*Config, error) {
	c := &Config{}

	required := map[string]*string{
		"BAT_DIRECTOR":        &c.Director,
		"BOSH_CLIENT":         &c.Client,
		"BOSH_CLIENT_SECRET":  &c.ClientSecret,
		"BOSH_CA_CERT":        &c.CACert,
		"BAT_STEMCELL":        &c.StemcellPath,
		"BAT_DEPLOYMENT_SPEC": nil, // handled separately below
	}
	for k, v := range required {
		if v == nil {
			continue
		}
		*v = os.Getenv(k)
		if *v == "" {
			return nil, fmt.Errorf("required env var %s is not set", k)
		}
	}

	c.AllProxy = os.Getenv("BOSH_ALL_PROXY")

	specPath := os.Getenv("BAT_DEPLOYMENT_SPEC")
	if specPath == "" {
		return nil, fmt.Errorf("required env var BAT_DEPLOYMENT_SPEC is not set")
	}
	if err := c.loadSpec(specPath); err != nil {
		return nil, fmt.Errorf("loading BAT_DEPLOYMENT_SPEC %s: %w", specPath, err)
	}

	return c, nil
}

func (c *Config) loadSpec(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	var f batsConfigFile
	if err := yaml.Unmarshal(data, &f); err != nil {
		return err
	}
	c.BATs = f.Properties
	return nil
}

// PrimaryNetwork returns the first network entry (the "default" manual network).
func (c *Config) PrimaryNetwork() Network {
	for _, n := range c.BATs.Networks {
		if n.Name == "default" {
			return n
		}
	}
	return c.BATs.Networks[0]
}

// SecondaryNetwork returns the second network entry if present.
func (c *Config) SecondaryNetwork() (Network, bool) {
	for _, n := range c.BATs.Networks {
		if n.Name == "second" {
			return n, true
		}
	}
	return Network{}, false
}
