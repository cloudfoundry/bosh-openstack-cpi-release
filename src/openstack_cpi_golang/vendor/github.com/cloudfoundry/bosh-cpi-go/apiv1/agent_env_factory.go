package apiv1

import (
	"encoding/json"

	bosherr "github.com/cloudfoundry/bosh-utils/errors"
)

type AgentEnvFactory struct{}

func NewAgentEnvFactory() AgentEnvFactory {
	return AgentEnvFactory{}
}

func (f AgentEnvFactory) FromBytes(bytes []byte) (AgentEnv, error) {
	var agentEnvSpec agentEnvSpec

	err := json.Unmarshal(bytes, &agentEnvSpec)
	if err != nil {
		return nil, bosherr.WrapError(err, "Unmarshalling agent env")
	}

	return &AgentEnvImpl{agentEnvSpec}, nil
}

func (f AgentEnvFactory) ForVM(
	agentID AgentID, cid VMCID, networks Networks, env VMEnv, agentOptions AgentOptions) AgentEnv {

	networksSpec := NetworksSpec{}

	for netName, network := range networks {
		typedNet := network.(*NetworkImpl)

		networksSpec[netName] = NetworkSpec{
			Type: typedNet.spec.Type,

			IP:      typedNet.IP(),
			Netmask: typedNet.Netmask(),
			Gateway: typedNet.Gateway(),

			DNS:     typedNet.spec.DNS,
			Default: typedNet.spec.Default,
			Routes:  typedNet.spec.Routes,
			Alias:   typedNet.spec.Alias,
			MAC:     typedNet.mac,

			Preconfigured: typedNet.preconfigured,
		}
	}

	agentEnvSpec := agentEnvSpec{
		AgentID: agentID.AsString(),

		VM: VMSpec{
			Name: cid.AsString(), // id for name and id
			ID:   cid.AsString(),
		},

		Mbus: agentOptions.Mbus,
		NTP:  agentOptions.NTP,

		Networks: networksSpec,

		Env: EnvSpec(env.val), // todo deep copy env?
	}

	return &AgentEnvImpl{agentEnvSpec}
}
