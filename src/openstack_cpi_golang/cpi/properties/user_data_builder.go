package properties

import (
	"encoding/json"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
)

type userDataBuilder struct {
	server            Server
	networks          map[string]UserdataNetwork
	dns               DNS
	vm                VM
	agentID           string
	ephemeralDiskSize int
	env               json.RawMessage
	disks             Disks
	mbus              string
}

func NewUserDataBuilder() userDataBuilder {
	return userDataBuilder{disks: Disks{System: "/dev/sda"}}
}

func (u userDataBuilder) WithServer(server Server) userDataBuilder {
	u.server = server

	return u
}

func (u userDataBuilder) WithConfig(config config.CpiConfig) userDataBuilder {
	u.mbus = config.Cloud.Properties.Agent.MBus

	return u
}

func (u userDataBuilder) WithNetworks(networks map[string]UserdataNetwork) userDataBuilder {
	u.networks = networks

	allDNSServers := make([]string, 0)
	for _, network := range u.networks {
		allDNSServers = append(allDNSServers, network.DNS...)
	}

	u.dns = DNS{Nameserver: utils.UniqueArray(allDNSServers)}

	return u
}

func (u userDataBuilder) WithVM(vm VM) userDataBuilder {
	u.vm = vm

	return u
}

func (u userDataBuilder) WithEphemeralDiskSize(diskSize int) userDataBuilder {
	u.ephemeralDiskSize = diskSize

	return u
}

func (u userDataBuilder) WithAgentID(agentID apiv1.AgentID) userDataBuilder {
	u.agentID = agentID.AsString()

	return u
}

func (u userDataBuilder) WithEnvironment(env json.RawMessage) userDataBuilder {
	u.env = env

	return u
}

func (u userDataBuilder) Build() UserData {
	if u.ephemeralDiskSize > 0 {
		u.disks.Ephemeral = "/dev/sdb"
	}

	return UserData{
		Server:   u.server,
		Networks: u.networks,
		DNS:      u.dns,
		VM:       u.vm,
		Disks:    u.disks,
		AgentID:  u.agentID,
		Env:      u.env,
		MBus:     u.mbus,
	}
}
