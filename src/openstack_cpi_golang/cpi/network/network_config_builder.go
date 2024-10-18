package network

import (
	"fmt"
	"slices"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
)

type networkConfigBuilder struct {
	securityGroupsResolver SecurityGroupsResolver
	networks               apiv1.Networks
	openstackConfig        config.OpenstackConfig
	cloudProps             properties.CreateVM
	logger                 utils.Logger
}

func NewNetworkConfigBuilder(
	securityGroupsResolver SecurityGroupsResolver,
	networks apiv1.Networks,
	openstackConfig config.OpenstackConfig,
	cloudProps properties.CreateVM,
	logger utils.Logger,
) networkConfigBuilder {
	return networkConfigBuilder{
		securityGroupsResolver: securityGroupsResolver,
		networks:               networks,
		openstackConfig:        openstackConfig,
		cloudProps:             cloudProps,
		logger:                 logger,
	}
}

func (b networkConfigBuilder) Build() (properties.NetworkConfig, error) {
	defaultNetwork := b.createNetwork("", b.networks.Default())

	manualNetworks, err := b.createManualNetwork(b.networks, b.openstackConfig)
	if err != nil {
		return properties.NetworkConfig{}, fmt.Errorf("invalid manual network configuration: %w", err)
	}

	vipNetwork, err := b.createSingleNetwork(b.networks, "vip")
	if err != nil {
		return properties.NetworkConfig{}, fmt.Errorf("invalid vip network configuration: %w", err)
	}

	dynamicNetwork, err := b.createSingleNetwork(b.networks, "dynamic")
	if err != nil {
		return properties.NetworkConfig{}, fmt.Errorf("invalid dynamic network configuration: %w", err)
	}

	err = b.validateNetIDs(b.combineNetworks(manualNetworks, dynamicNetwork, nil))
	if err != nil {
		return properties.NetworkConfig{}, fmt.Errorf("invalid network configuration: %w", err)
	}

	securityGroups, err := b.securityGroups(b.combineNetworks(manualNetworks, dynamicNetwork, vipNetwork))
	if err != nil {
		return properties.NetworkConfig{}, fmt.Errorf("invalid security group configuration: %w", err)
	}

	resultNetworkConfig := properties.NetworkConfig{
		DefaultNetwork: defaultNetwork,
		ManualNetworks: manualNetworks,
		VIPNetwork:     vipNetwork,
		DynamicNetwork: dynamicNetwork,
		SecurityGroups: securityGroups,
	}

	return resultNetworkConfig, nil
}

func (b networkConfigBuilder) securityGroups(networks []properties.Network) ([]string, error) {
	var securityGroups []string

	securityGroups = b.cloudProps.SecurityGroups
	if len(securityGroups) == 0 {

		securityGroups = b.securityGroupsFromNetworks(networks)
		if len(securityGroups) == 0 {

			securityGroups = b.openstackConfig.DefaultSecurityGroups
		}

	}

	securityGroupIDs, err := b.securityGroupsResolver.Resolve(securityGroups)
	if err != nil {
		return []string{}, fmt.Errorf("failed to resolve security group: %w", err)
	}

	b.logger.Info("network-config-builder", "resolved security groups ids: %v", securityGroupIDs)
	return securityGroupIDs, nil
}

func (b networkConfigBuilder) securityGroupsFromNetworks(networks []properties.Network) []string {
	var securityGroups []string

	for _, network := range networks {
		securityGroups = append(securityGroups, network.CloudProps.SecurityGroups...)
	}

	return utils.UniqueArray(securityGroups)
}

func (b networkConfigBuilder) combineNetworks(manualNetworks []properties.Network, dynamicNetwork *properties.Network, vipNetwork *properties.Network) []properties.Network {
	var networks []properties.Network

	networks = append(networks, manualNetworks...)

	if dynamicNetwork != nil {
		networks = append(networks, *dynamicNetwork)
	}

	if vipNetwork != nil {
		networks = append(networks, *vipNetwork)
	}

	return networks
}

func (b networkConfigBuilder) createManualNetwork(networks apiv1.Networks, openstackConfig config.OpenstackConfig) ([]properties.Network, error) {
	var manualNetworks []properties.Network

	for key, network := range networks {
		if network.Type() == "manual" {
			createdNetwork := b.createNetwork(key, network)

			netID := createdNetwork.CloudProps.NetID
			if netID == "" {
				return []properties.Network{}, fmt.Errorf("manual network must have a net_id")
			}

			manualNetworks = append(manualNetworks, createdNetwork)
		}
	}

	if len(manualNetworks) > 1 {
		if openstackConfig.UseDHCP || openstackConfig.ConfigDrive != "" {
			return []properties.Network{}, fmt.Errorf("multiple manual networks can only be used with 'openstack.use_dhcp=false' and 'openstack.config_drive=cdrom|disk'")
		}
	}

	return manualNetworks, nil
}

func (b networkConfigBuilder) createSingleNetwork(networks apiv1.Networks, networkType string) (*properties.Network, error) {
	var network *properties.Network

	for key, net := range networks {
		if net.Type() == networkType {
			if network != nil {
				return &properties.Network{}, fmt.Errorf("only one %s should be defined per instance", networkType)
			}

			createdNetwork := b.createNetwork(key, net)
			network = &createdNetwork
		}
	}

	return network, nil
}

func (b networkConfigBuilder) createNetwork(key string, network apiv1.Network) properties.Network {
	vmNetworkProps := properties.NetworkCloudProps{}
	err := network.CloudProps().As(&vmNetworkProps)
	if err != nil {
		return properties.Network{}
	}

	return properties.Network{
		Key:        key,
		Default:    network.Default(),
		DNS:        network.DNS(),
		IP:         network.IP(),
		Gateway:    network.Gateway(),
		Netmask:    network.Netmask(),
		Type:       network.Type(),
		CloudProps: vmNetworkProps,
	}
}

func (b networkConfigBuilder) validateNetIDs(networks []properties.Network) error {
	var usedNetIDs []string

	for _, network := range networks {
		netID := network.CloudProps.NetID
		if slices.Contains(usedNetIDs, netID) {
			return fmt.Errorf("network with id %s is defined multiple times", netID)
		}

		usedNetIDs = append(usedNetIDs, netID)
	}

	return nil
}
