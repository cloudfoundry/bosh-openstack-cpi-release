package properties

import "encoding/json"

type UserData struct {
	Server   Server                     `json:"server"`
	Networks map[string]UserdataNetwork `json:"networks"`
	DNS      DNS                        `json:"dns"`
	VM       VM                         `json:"vm"`
	Disks    Disks                      `json:"disks"`
	AgentID  string                     `json:"agent_id"`
	Env      json.RawMessage            `json:"env"`
	MBus     string                     `json:"mbus"`
}

type Server struct {
	Name string `json:"name"`
}

type OpenSSH struct {
	PublicKey string `json:"public_key"`
}

type UserdataNetwork struct {
	Default       []string          `json:"default"`
	DNS           []string          `json:"dns"`
	IP            string            `json:"ip"`
	Gateway       string            `json:"gateway,omitempty"`
	Mac           string            `json:"mac,omitempty"`
	Netmask       string            `json:"netmask,omitempty"`
	Preconfigured *bool             `json:"preconfigured,omitempty"`
	Resolved      *bool             `json:"resolved,omitempty"`
	Type          string            `json:"type"`
	UseDHCP       *bool             `json:"use_dhcp,omitempty"`
	CloudProps    NetworkCloudProps `json:"cloud_properties"`
}

type DNS struct {
	Nameserver []string `json:"nameserver"`
}

type VM struct {
	Name string `json:"name"`
}

type Disks struct {
	System     string   `json:"system"`
	Persistent struct{} `json:"persistent"`
	Ephemeral  string   `json:"ephemeral"`
}
