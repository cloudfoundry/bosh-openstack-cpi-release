package apiv1

import (
	"encoding/json"

	bosherr "github.com/cloudfoundry/bosh-utils/errors"
)

type AgentEnv interface {
	AttachSystemDisk(DiskHint)
	AttachEphemeralDisk(DiskHint)
	AttachPersistentDisk(DiskCID, DiskHint)
	DetachPersistentDisk(DiskCID)
	AsBytes() ([]byte, error)
	_final() // interface unimplementable from outside
}

type AgentEnvImpl struct {
	spec agentEnvSpec
}

var _ AgentEnv = &AgentEnvImpl{}

type agentEnvSpec struct {
	AgentID string `json:"agent_id"`

	VM VMSpec `json:"vm"`

	Mbus string   `json:"mbus"`
	NTP  []string `json:"ntp"`

	Networks NetworksSpec `json:"networks"`

	Disks DisksSpec `json:"disks"`

	Env EnvSpec `json:"env"`
}

type VMSpec struct {
	Name string `json:"name"`
	ID   string `json:"id"`
}

type NetworksSpec map[string]NetworkSpec

type NetworkSpec struct {
	Type string `json:"type"`

	IP      string `json:"ip"`
	Netmask string `json:"netmask"`
	Gateway string `json:"gateway"`

	DNS     []string `json:"dns"`
	Default []string `json:"default"`
	Routes  []Route  `json:"routes"`
	Alias   string   `json:"alias,omitempty"`

	MAC string `json:"mac"`

	Preconfigured bool `json:"preconfigured"`
}

type DisksSpec struct {
	System     DiskHint       `json:"system"`
	Ephemeral  DiskHint       `json:"ephemeral"`
	Persistent PersistentSpec `json:"persistent"`
}

type PersistentSpec map[string]DiskHint

type EnvSpec map[string]interface{}

func (ae *AgentEnvImpl) AttachSystemDisk(hint DiskHint) {
	ae.spec.Disks.System = hint
}

func (ae *AgentEnvImpl) AttachEphemeralDisk(hint DiskHint) {
	ae.spec.Disks.Ephemeral = hint
}

func (ae *AgentEnvImpl) AttachPersistentDisk(cid DiskCID, hint DiskHint) { // TODO better type for hint
	spec := PersistentSpec{}

	if ae.spec.Disks.Persistent != nil {
		for k, v := range ae.spec.Disks.Persistent {
			spec[k] = v
		}
	}

	spec[cid.AsString()] = hint

	ae.spec.Disks.Persistent = spec
}

func (ae *AgentEnvImpl) DetachPersistentDisk(cid DiskCID) {
	spec := PersistentSpec{}

	if ae.spec.Disks.Persistent != nil {
		for k, v := range ae.spec.Disks.Persistent {
			spec[k] = v
		}
	}

	delete(spec, cid.AsString())

	ae.spec.Disks.Persistent = spec
}

func (ae AgentEnvImpl) AsBytes() ([]byte, error) {
	bytes, err := json.Marshal(ae.spec)
	if err != nil {
		return nil, bosherr.WrapError(err, "Marshalling agent env")
	}

	return bytes, nil
}

func (ae AgentEnvImpl) _final() {}
