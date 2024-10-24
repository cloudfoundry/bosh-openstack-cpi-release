package network

import (
	"errors"
	"fmt"
	"net"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/gophercloud/gophercloud"
	"github.com/gophercloud/gophercloud/openstack/networking/v2/extensions/layer3/floatingips"
	"github.com/gophercloud/gophercloud/openstack/networking/v2/ports"
	"github.com/gophercloud/gophercloud/openstack/networking/v2/subnets"
)

//counterfeiter:generate . NetworkService
type NetworkService interface {
	ConfigureVIPNetwork(
		instanceId string,
		networkConfig properties.NetworkConfig,
	) error

	GetNetworkConfiguration(
		networks apiv1.Networks,
		openstackConfig config.OpenstackConfig,
		cloudProps properties.CreateVM,
	) (properties.NetworkConfig, error)

	GetSubnetID(networkID string, ip string) (string, error)

	CreatePort(networkConfig properties.Network, securityGroups []string, cloudProperties properties.CreateVM) (ports.Port, error)

	GetPorts(
		instanceId string,
		defaultNetwork properties.Network,
		retryable bool,
	) ([]ports.Port, error)

	DeletePorts(
		ports []ports.Port,
	) error
}

type networkService struct {
	serviceClients   utils.ServiceClients
	networkingFacade NetworkingFacade
	logger           utils.Logger
}

func NewNetworkService(
	serviceClients utils.ServiceClients,
	networkingFacade NetworkingFacade,
	logger utils.Logger,
) networkService {
	return networkService{
		serviceClients:   serviceClients,
		networkingFacade: networkingFacade,
		logger:           logger,
	}
}

func (c networkService) ConfigureVIPNetwork(
	instanceId string,
	networkConfig properties.NetworkConfig,
) error {
	vipNetwork := networkConfig.VIPNetwork

	if vipNetwork != nil {
		floatingIp, err := c.getFloatingIp(vipNetwork)
		if err != nil {
			return fmt.Errorf("failed to get floating IP: %w", err)
		}

		instancePorts, err := c.GetPorts(instanceId, networkConfig.DefaultNetwork, false)
		if err != nil {
			return fmt.Errorf("failed to get port: %w", err)
		}
		if len(instancePorts) == 0 {
			return fmt.Errorf("no port allocated by instance %s and network %s", instanceId, networkConfig.DefaultNetwork.CloudProps.NetID)
		}

		err = c.associateFloatingIp(floatingIp.ID, instancePorts[0].ID)
		if err != nil {
			return fmt.Errorf("failed to associate floating ip to port: %w", err)
		}
	}
	return nil
}

func (c networkService) GetNetworkConfiguration(
	networks apiv1.Networks,
	openstackConfig config.OpenstackConfig,
	cloudProps properties.CreateVM,
) (properties.NetworkConfig, error) {
	securityGroupsResolver := NewSecurityGroupsResolver(c.serviceClients, c.networkingFacade, c.logger)

	networkProperties, err := NewNetworkConfigBuilder(securityGroupsResolver, networks, openstackConfig, cloudProps, c.logger).Build()
	return networkProperties, err
}

func (c networkService) GetSubnetID(networkID string, ip string) (string, error) {
	ipAddress := net.ParseIP(ip)
	if ipAddress == nil {
		return "", fmt.Errorf("failed to parse ip address '%s'", ip)
	}

	listOpts := subnets.ListOpts{
		NetworkID: networkID,
	}

	allPages, err := c.networkingFacade.ListSubnets(c.serviceClients.RetryableServiceClient, listOpts)
	if err != nil {
		return "", fmt.Errorf("failed to list subnets: %w", err)
	}

	allSubnets, err := c.networkingFacade.ExtractSubnets(allPages)
	if err != nil {
		return "", fmt.Errorf("failed to extract subnets: %w", err)
	}

	if len(allSubnets) == 0 {
		return "", fmt.Errorf("no subnet found for network '%s'", networkID)
	}

	var matchingSubnets []string
	for _, subnet := range allSubnets {
		_, ipNet, err := net.ParseCIDR(subnet.CIDR)
		if ipNet == nil {
			return "", fmt.Errorf("failed to parse subnet cidr '%s': %w", subnet.CIDR, err)
		}

		if ipNet.Contains(ipAddress) {
			matchingSubnets = append(matchingSubnets, subnet.ID)
		}
	}

	if len(matchingSubnets) > 1 {
		return "", fmt.Errorf("found more than one matching subnet for the ip '%s' in '%v'", ipAddress, matchingSubnets)
	} else if len(matchingSubnets) == 0 {
		return "", fmt.Errorf("no matching subnet found for the ip '%s'", ipAddress)
	}

	return matchingSubnets[0], nil
}

func (c networkService) CreatePort(network properties.Network, securityGroups []string, cloudProperties properties.CreateVM) (ports.Port, error) {
	createOpts, err := c.getPortCreationNetworkOpts(network, securityGroups, cloudProperties)
	if err != nil {
		return ports.Port{}, fmt.Errorf("failed create network opts: %w", err)
	}

	c.logger.Info("network-service", fmt.Sprintf("creating port with opts '%+v', using security groups %v", createOpts, securityGroups))

	createdPort, err := c.networkingFacade.CreatePort(c.serviceClients.ServiceClient, createOpts)
	if err != nil {
		c.logger.Warn("network-service",
			fmt.Sprintf("failed to create port on network '%s' for ip '%s': %v",
				network.CloudProps.NetID, network.IP, err))
		c.logger.Warn("network-service", "checking for conflicting ports now")

		listOpts := ports.ListOpts{
			NetworkID: network.CloudProps.NetID,
			FixedIPs:  []ports.FixedIPOpts{{IPAddress: network.IP}},
		}
		page, err := c.networkingFacade.ListPorts(c.serviceClients.RetryableServiceClient, listOpts)
		if err != nil {
			return ports.Port{}, fmt.Errorf("failed to list Ports: %w", err)
		}

		existingPorts, err := c.networkingFacade.ExtractPorts(page)
		if err != nil {
			return ports.Port{}, fmt.Errorf("failed to extract ports: %w", err)
		}

		for _, port := range existingPorts {
			if port.Status == "DOWN" && port.DeviceID == "" && port.DeviceOwner == "" {
				c.logger.Warn("network-service", fmt.Sprintf("port on network '%s' for ip '%s' "+
					"is already allocated but unused, deleting conflicting port now.",
					network.CloudProps.NetID, network.IP))

				err := c.networkingFacade.DeletePort(c.serviceClients.RetryableServiceClient, port.ID)
				if err != nil {
					return ports.Port{}, fmt.Errorf("failed to delete port: %w", err)
				}
			}
		}

		createdPort, err = c.networkingFacade.CreatePort(c.serviceClients.ServiceClient, createOpts)
		if err != nil {
			return ports.Port{}, fmt.Errorf("failed to recreate port on network '%s' for ip '%s' %w",
				network.CloudProps.NetID, network.IP, err)
		}

		if createdPort == nil {
			return ports.Port{}, fmt.Errorf("failed to create port for network '%s' with ip '%s'. Port must not be nil",
				network.CloudProps.NetID, network.IP)
		}

		c.logger.Info("network-service",
			fmt.Sprintf("recreated port with id '%s' on network '%s' for ip '%s'",
				createdPort.ID, network.CloudProps.NetID, network.IP))
	}

	return *createdPort, nil
}

func (c networkService) GetPorts(instanceId string, defaultNetwork properties.Network, retryable bool) ([]ports.Port, error) {
	listOpts := ports.ListOpts{
		DeviceID: instanceId,
	}

	if defaultNetwork.CloudProps.NetID != "" {
		listOpts.NetworkID = defaultNetwork.CloudProps.NetID
	}

	allPages, err := c.networkingFacade.ListPorts(c.serviceClients.RetryableServiceClient, listOpts)
	if err != nil {
		return []ports.Port{}, fmt.Errorf("failed to list ports: %w", err)
	}

	allPorts, err := c.networkingFacade.ExtractPorts(allPages)
	if err != nil {
		return []ports.Port{}, fmt.Errorf("failed to extract ports: %w", err)
	}

	return allPorts, nil
}

func (c networkService) DeletePorts(ports []ports.Port) error {
	var errDefault404 gophercloud.ErrDefault404

	for _, port := range ports {
		err := c.networkingFacade.DeletePort(c.serviceClients.RetryableServiceClient, port.ID)
		if err != nil {
			if errors.As(err, &errDefault404) {
				c.logger.Info("network_service", fmt.Sprintf("SKIPPING: Port deletion with id '%s' is not found", port.ID))
				return nil
			}
			return fmt.Errorf("failed to delete port: %w", err)
		}
		c.logger.Info("network_service", fmt.Sprintf("Deleted port with id '%s'", port.ID))
	}

	return nil
}

func (c networkService) getPortCreationNetworkOpts(
	network properties.Network,
	securityGroups []string,
	cloudProperties properties.CreateVM,
) (ports.CreateOpts, error) {
	subnetID, err := c.GetSubnetID(network.CloudProps.NetID, network.IP)
	if err != nil {
		return ports.CreateOpts{}, fmt.Errorf("failed to get subnet: %w", err)
	}

	createOpts := ports.CreateOpts{
		NetworkID: network.CloudProps.NetID,
		FixedIPs: []ports.IP{
			{SubnetID: subnetID, IPAddress: network.IP},
		},
		SecurityGroups: &securityGroups,
	}

	if cloudProperties.AllowedAddressPairs != "" {
		vrrpPortExisting, err := c.isVRRPPortExisting(cloudProperties)
		if err != nil {
			return ports.CreateOpts{}, fmt.Errorf("VRRP port existence check failed: %w", err)
		}

		if !vrrpPortExisting {
			return ports.CreateOpts{}, fmt.Errorf("configured VRRP port with ip '%s' does not exist", cloudProperties.AllowedAddressPairs)
		}

		createOpts.AllowedAddressPairs = []ports.AddressPair{{IPAddress: cloudProperties.AllowedAddressPairs}}
	}
	return createOpts, nil
}

func (c networkService) isVRRPPortExisting(cloudProperties properties.CreateVM) (bool, error) {
	vrrpPortCheck := cloudProperties.VRRPPortCheck
	if vrrpPortCheck != nil && *vrrpPortCheck {
		listOpts := ports.ListOpts{
			FixedIPs: []ports.FixedIPOpts{{IPAddress: cloudProperties.AllowedAddressPairs}},
		}
		page, err := c.networkingFacade.ListPorts(c.serviceClients.RetryableServiceClient, listOpts)
		if err != nil {
			return false, fmt.Errorf("failed to list VRRP ports: %w", err)
		}

		vrrpPorts, err := c.networkingFacade.ExtractPorts(page)
		if err != nil {
			return false, fmt.Errorf("failed to extract VRRP ports: %w", err)
		}

		if len(vrrpPorts) == 0 {
			return false, nil
		}
	}
	return true, nil
}

func (c networkService) getFloatingIp(vipNetwork *properties.Network) (floatingips.FloatingIP, error) {
	listOpts := floatingips.ListOpts{
		FloatingIP: vipNetwork.IP,
	}

	allPages, err := c.networkingFacade.ListFloatingIps(c.serviceClients.RetryableServiceClient, listOpts)
	if err != nil {
		return floatingips.FloatingIP{}, fmt.Errorf("failed to list floating IPs: %w", err)
	}

	allFIPs, err := c.networkingFacade.ExtractFloatingIPs(allPages)
	if err != nil {
		return floatingips.FloatingIP{}, fmt.Errorf("failed to extract floating IPs: %w", err)
	}

	if len(allFIPs) == 0 {
		return floatingips.FloatingIP{}, fmt.Errorf("floating IP %s not allocated", vipNetwork.IP)
	}

	return allFIPs[0], err
}

func (c networkService) associateFloatingIp(floatingIpId string, portId string) error {
	updateOpts := floatingips.UpdateOpts{
		PortID: &portId,
	}

	_, err := c.networkingFacade.UpdateFloatingIP(c.serviceClients.ServiceClient, floatingIpId, updateOpts)
	return err
}
