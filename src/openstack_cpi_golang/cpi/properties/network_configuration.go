package properties

import (
	"github.com/gophercloud/gophercloud/openstack/networking/v2/ports"
)

type NetworkConfig struct {
	DefaultNetwork Network
	ManualNetworks []Network
	VIPNetwork     *Network
	DynamicNetwork *Network
	SecurityGroups []string
}

type Network struct {
	Key        string
	Port       ports.Port
	Default    []string          `json:"default"`
	DNS        []string          `json:"dns"`
	IP         string            `json:"ip,omitempty"`
	Gateway    string            `json:"gateway,omitempty"`
	Netmask    string            `json:"netmask,omitempty"`
	Type       string            `json:"type"`
	CloudProps NetworkCloudProps `json:"cloud_properties"`
	Mac        string            `json:"mac,omitempty"`
}

func (n *Network) ConfigurePort(port ports.Port) {
	n.Port = port
	n.Mac = port.MACAddress
}

type NetworkCloudProps struct {
	NetID          string   `json:"net_id,omitempty"`
	SecurityGroups []string `json:"security_groups,omitempty"`
}

func (n *NetworkConfig) AllNetworks() []Network {
	networks := n.ManualNetworks

	if n.DynamicNetwork != nil {
		networks = append(networks, *n.DynamicNetwork)
	}

	if n.VIPNetwork != nil {
		networks = append(networks, *n.VIPNetwork)
	}

	return networks
}
