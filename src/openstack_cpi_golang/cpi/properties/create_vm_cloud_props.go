package properties

import (
	"fmt"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
)

type CreateVM struct {
	AllowedAddressPairs string             `json:"allowed_address_pairs"`
	AvailabilityZone    string             `json:"availability_zone"`
	AvailabilityZones   []string           `json:"availability_zones"`
	BootFromVolume      *bool              `json:"boot_from_volume,omitempty"`
	EphemeralDisk       string             `json:"ephemeral_disk"`
	InstanceType        string             `json:"instance_type"`
	KeyName             string             `json:"key_name"`
	LoadbalancerPools   []LoadbalancerPool `json:"loadbalancer_pools"`
	RootDisk            Disk               `json:"root_disk,omitempty"`
	SchedulerHints      string             `json:"scheduler_hints"`
	SecurityGroups      []string           `json:"security_groups"`
	VRRPPortCheck       *bool              `json:"vrrp_port_check,omitempty"`
}

type Disk struct {
	Size int `json:"size"`
}

type LoadbalancerPool struct {
	Name           string `json:"name"`
	ProtocolPort   int    `json:"port"`
	MonitoringPort *int   `json:"monitoring_port,omitempty"`
}

func (c CreateVM) Validate(opentackConfig config.OpenstackConfig) error {

	for _, pool := range c.LoadbalancerPools {
		if pool.Name == "" {
			return fmt.Errorf("load balancer pool defined without name")
		}
		if pool.ProtocolPort == 0 {
			return fmt.Errorf("load balancer pool '%s' has no port definition", pool.Name)
		}
	}

	if c.AvailabilityZone != "" && len(c.AvailabilityZones) > 0 {
		return fmt.Errorf("only one property of 'availability_zone' and 'availability_zones' can be configured")
	}

	if len(c.AvailabilityZones) > 1 && !opentackConfig.IgnoreServerAvailabilityZone {
		return fmt.Errorf("cannot use multiple azs without 'openstack.ignore_server_availability_zone' set to true")
	}
	return nil
}
