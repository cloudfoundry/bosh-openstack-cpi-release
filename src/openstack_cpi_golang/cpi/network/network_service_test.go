package network_test

import (
	"errors"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/mocks"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/network"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/network/networkfakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	"github.com/gophercloud/gophercloud"
	"github.com/gophercloud/gophercloud/openstack/networking/v2/extensions/layer3/floatingips"
	"github.com/gophercloud/gophercloud/openstack/networking/v2/ports"
	"github.com/gophercloud/gophercloud/openstack/networking/v2/subnets"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("NetworkService", func() {
	var serviceClient gophercloud.ServiceClient
	var retryableServiceClient gophercloud.ServiceClient
	var serviceClients utils.ServiceClients
	var utilsRetryableServiceClient utils.RetryableServiceClient
	var defaultNetwork properties.Network
	var networkConfig properties.NetworkConfig
	var networkingFacade networkfakes.FakeNetworkingFacade
	var logger utilsfakes.FakeLogger
	var floatingIpPage mocks.MockPage
	var portPage mocks.MockPage
	var subnetsPage mocks.MockPage

	BeforeEach(func() {
		serviceClient = gophercloud.ServiceClient{}
		retryableServiceClient = gophercloud.ServiceClient{}
		serviceClients = utils.ServiceClients{ServiceClient: &serviceClient, RetryableServiceClient: &retryableServiceClient}
		networkingFacade = networkfakes.FakeNetworkingFacade{}
		logger = utilsfakes.FakeLogger{}
		floatingIpPage = mocks.MockPage{}
		portPage = mocks.MockPage{}
		subnetsPage = mocks.MockPage{}

		networkingFacade.ListFloatingIpsReturns(floatingIpPage, nil)
		networkingFacade.ExtractFloatingIPsReturns([]floatingips.FloatingIP{{ID: "the_floating_ip_id"}}, nil)
		networkingFacade.ListPortsReturns(portPage, nil)
		networkingFacade.ExtractPortsReturns([]ports.Port{{ID: "5678"}}, nil)
		networkingFacade.ListSubnetsReturns(subnetsPage, nil)
		networkingFacade.ExtractSubnetsReturns([]subnets.Subnet{
			{ID: "the-subnet-id-1", CIDR: "1.1.1.0/24"}, {ID: "the-subnet-id-2", CIDR: "1.1.2.0/24"},
		}, nil)

		defaultNetwork = properties.Network{
			IP: "1.1.1.1",
			CloudProps: properties.NetworkCloudProps{
				NetID: "the_net_id_1",
			},
		}
		networkConfig = properties.NetworkConfig{
			DefaultNetwork: defaultNetwork,
			VIPNetwork:     &properties.Network{IP: "3.3.3.3"},
			SecurityGroups: []string{"sec-id1", "sec-id2"},
		}
	})

	Context("ConfigureVIPNetwork", func() {
		It("lists floating ips", func() {
			_ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).ConfigureVIPNetwork("123-456", networkConfig)

			_, listOpts := networkingFacade.ListFloatingIpsArgsForCall(0)
			Expect(listOpts.FloatingIP).To(Equal("3.3.3.3"))
		})

		It("returns an error if floating ips cannot be fetched from openstack", func() {
			networkingFacade.ListFloatingIpsReturns(nil, errors.New("boom"))

			err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).ConfigureVIPNetwork("123-456", networkConfig)
			Expect(err.Error()).To(Equal("failed to get floating IP: failed to list floating IPs: boom"))
		})

		It("extracts floating ips", func() {
			_ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).ConfigureVIPNetwork("123-456", networkConfig)

			pages := networkingFacade.ExtractFloatingIPsArgsForCall(0)
			Expect(pages).To(Equal(floatingIpPage))
		})

		It("returns an error if floating ips cannot be extracted from pages", func() {
			networkingFacade.ExtractFloatingIPsReturns(nil, errors.New("boom"))

			err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).ConfigureVIPNetwork("123-456", networkConfig)
			Expect(err.Error()).To(Equal("failed to get floating IP: failed to extract floating IPs: boom"))
		})

		It("returns an error if floating ips are empty", func() {
			networkingFacade.ExtractFloatingIPsReturns([]floatingips.FloatingIP{}, nil)

			err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).ConfigureVIPNetwork("123-456", networkConfig)
			Expect(err.Error()).To(Equal("failed to get floating IP: floating IP 3.3.3.3 not allocated"))
		})

		It("gets ports", func() {
			_ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).ConfigureVIPNetwork("123-456", networkConfig)

			serviceClient, listOpts := networkingFacade.ListPortsArgsForCall(0)
			Expect(listOpts.DeviceID).To(Equal("123-456"))
			Expect(listOpts.NetworkID).To(Equal("the_net_id_1"))

			Expect(serviceClient).To(BeAssignableToTypeOf(utilsRetryableServiceClient))
		})

		It("returns an error if getting ports failed", func() {
			networkingFacade.ListPortsReturns(nil, errors.New("boom"))

			err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).ConfigureVIPNetwork("123-456", networkConfig)
			Expect(err.Error()).To(Equal("failed to get port: failed to list ports: boom"))
		})

		It("returns an error if no ports are allocated", func() {
			networkingFacade.ExtractPortsReturns([]ports.Port{}, nil)

			err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).ConfigureVIPNetwork("123-456", networkConfig)
			Expect(err.Error()).To(Equal("no port allocated by instance 123-456 and network the_net_id_1"))
		})

		It("associates the floating ip to a port", func() {
			_ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).ConfigureVIPNetwork("123-456", networkConfig)

			_, floatingIpId, updateOpts := networkingFacade.UpdateFloatingIPArgsForCall(0)
			Expect(floatingIpId).To(Equal("the_floating_ip_id"))
			Expect(*updateOpts.PortID).To(Equal("5678"))
		})

		It("returns an error if port association fails", func() {
			networkingFacade.UpdateFloatingIPReturns(nil, errors.New("boom"))

			err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).ConfigureVIPNetwork("123-456", networkConfig)
			Expect(err.Error()).To(Equal("failed to associate floating ip to port: boom"))
		})
	})

	Context("GetSubnetID", func() {

		It("lists subnets", func() {
			_, _ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).GetSubnetID("the-net-id", "1.1.1.1")

			Expect(networkingFacade.ListSubnetsCallCount()).To(Equal(1))
		})

		It("returns an error if listing subnets fails", func() {
			networkingFacade.ListSubnetsReturns(nil, errors.New("boom"))

			_, err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).GetSubnetID("the-net-id", "1.1.1.1")

			Expect(err.Error()).To(Equal("failed to list subnets: boom"))
		})

		It("extracts subnets", func() {
			_, _ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).GetSubnetID("the-net-id", "1.1.1.1")

			page := networkingFacade.ExtractSubnetsArgsForCall(0)

			Expect(page).To(Equal(subnetsPage))
		})

		It("returns an error if extracting subnets fails", func() {
			networkingFacade.ExtractSubnetsReturns(nil, errors.New("boom"))

			_, err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).GetSubnetID("the-net-id", "1.1.1.1")

			Expect(err.Error()).To(Equal("failed to extract subnets: boom"))
		})

		It("returns an error if subnets are empty", func() {
			networkingFacade.ExtractSubnetsReturns([]subnets.Subnet{}, nil)

			_, err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).GetSubnetID("the-net-id", "1.1.1.1")

			Expect(err.Error()).To(Equal("no subnet found for network 'the-net-id'"))
		})

		It("calculates the matching subnet of the offered IP", func() {
			networkingFacade.ExtractSubnetsReturns([]subnets.Subnet{
				{ID: "the-subnet-id-1", CIDR: "1.1.1.0/24"}, {ID: "the-subnet-id-2", CIDR: "1.1.2.0/24"},
			}, nil)

			subnet, err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).GetSubnetID("the-net-id", "1.1.1.1")

			Expect(err).To(Not(HaveOccurred()))
			Expect(subnet).To(Equal("the-subnet-id-1"))
		})

		It("returns an error if subnet CIDR cannot be parsed", func() {
			networkingFacade.ExtractSubnetsReturns([]subnets.Subnet{
				{ID: "the-subnet-id-1", CIDR: "invalid-cidr"},
			}, nil)

			_, err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).GetSubnetID("the-net-id", "1.1.1.1")

			Expect(err.Error()).To(Equal("failed to parse subnet cidr 'invalid-cidr': invalid CIDR address: invalid-cidr"))
		})

		It("returns an error if multiple subnet CIDRs match the offered IP", func() {
			networkingFacade.ExtractSubnetsReturns([]subnets.Subnet{
				{ID: "the-subnet-id-1", CIDR: "1.1.1.0/24"}, {ID: "the-subnet-id-2", CIDR: "1.1.1.0/24"},
			}, nil)

			_, err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).GetSubnetID("the-net-id", "1.1.1.1")

			Expect(err.Error()).To(ContainSubstring("found more than one matching subnet for the ip"))
		})

		It("returns an error if no subnet CIDRs match the offered IP", func() {
			networkingFacade.ExtractSubnetsReturns([]subnets.Subnet{
				{ID: "the-subnet-id-1", CIDR: "1.1.1.0/24"}, {ID: "the-subnet-id-2", CIDR: "1.1.1.0/24"},
			}, nil)

			_, err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).GetSubnetID("the-net-id", "2.1.1.1")

			Expect(err.Error()).To(ContainSubstring("no matching subnet found for the ip '2.1.1.1'"))
		})

		It("returns the subnet ID of the matching subnet", func() {
			subnetID, err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).GetSubnetID("the-net-id", "1.1.1.1")

			Expect(err).To(Not(HaveOccurred()))
			Expect(subnetID).To(Equal("the-subnet-id-1"))
		})
	})

	Context("CreatePort", func() {

		var cloudProperties properties.CreateVM
		var createdPort ports.Port
		var securityGroups []string

		BeforeEach(func() {
			createdPort = ports.Port{ID: "the-port-id"}
			networkingFacade.CreatePortReturns(&createdPort, nil)
			networkingFacade.ExtractPortsReturns([]ports.Port{createdPort}, nil)
			securityGroups = []string{"sec-id1", "sec-id2"}

			vrrpPortCheck := true
			cloudProperties = properties.CreateVM{
				AllowedAddressPairs: "allowed-address-pairs",
				VRRPPortCheck:       &vrrpPortCheck,
			}
		})

		It("lists VRRP ports if the port check is enabled", func() {
			_, _ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).
				CreatePort(defaultNetwork, securityGroups, cloudProperties)

			Expect(networkingFacade.ListPortsCallCount()).To(Equal(1))
		})

		It("skips listing VRRP ports if the port check is not defined", func() {
			cloudProperties := properties.CreateVM{
				AllowedAddressPairs: "allowed-address-pairs",
			}
			_, _ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).
				CreatePort(defaultNetwork, securityGroups, cloudProperties)

			Expect(networkingFacade.ListPortsCallCount()).To(Equal(0))
		})

		It("skips listing VRRP ports if the port check is false", func() {
			cloudProperties := properties.CreateVM{
				AllowedAddressPairs: "allowed-address-pairs",
				VRRPPortCheck:       new(bool),
			}
			_, _ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).
				CreatePort(defaultNetwork, securityGroups, cloudProperties)

			Expect(networkingFacade.ListPortsCallCount()).To(Equal(0))
		})

		It("returns an error if listing VRRP ports fails", func() {
			networkingFacade.ListPortsReturns(nil, errors.New("boom"))

			_, err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).
				CreatePort(defaultNetwork, securityGroups, cloudProperties)

			Expect(err.Error()).To(Equal("failed create network opts: VRRP port existence check failed: " +
				"failed to list VRRP ports: boom"))
		})

		It("extracts VRRP ports if the port check is enabled", func() {
			_, _ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).
				CreatePort(defaultNetwork, securityGroups, cloudProperties)

			Expect(networkingFacade.ExtractPortsCallCount()).To(Equal(1))
		})

		It("returns an error if extracting VRRP ports fails", func() {
			networkingFacade.ExtractPortsReturns(nil, errors.New("boom"))

			_, err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).
				CreatePort(defaultNetwork, securityGroups, cloudProperties)

			Expect(err.Error()).To(Equal("failed create network opts: VRRP port existence check failed: " +
				"failed to extract VRRP ports: boom"))
		})

		It("returns an error if VRRP ports cannot be found", func() {
			networkingFacade.ExtractPortsReturns([]ports.Port{}, nil)

			_, err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).
				CreatePort(defaultNetwork, securityGroups, cloudProperties)

			Expect(err.Error()).To(Equal("failed create network opts: " +
				"configured VRRP port with ip 'allowed-address-pairs' does not exist"))
		})

		It("creates the port", func() {
			cloudProperties = properties.CreateVM{
				VRRPPortCheck: new(bool),
			}

			_, _ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).
				CreatePort(defaultNetwork, securityGroups, cloudProperties)

			_, createOpts := networkingFacade.CreatePortArgsForCall(0)

			Expect(createOpts.NetworkID).To(ContainSubstring("the_net_id_1"))
			Expect(createOpts.FixedIPs.([]ports.IP)[0].SubnetID).To(Equal("the-subnet-id-1"))
			Expect(createOpts.FixedIPs.([]ports.IP)[0].IPAddress).To(Equal("1.1.1.1"))

			securityGroups := *createOpts.SecurityGroups
			Expect(securityGroups[0]).To(Equal("sec-id1"))
			Expect(securityGroups[1]).To(Equal("sec-id2"))
			Expect(createOpts.AllowedAddressPairs).To(BeNil())

		})

		It("creates the port with VRRP port", func() {
			_, _ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).
				CreatePort(defaultNetwork, securityGroups, cloudProperties)

			_, createOpts := networkingFacade.CreatePortArgsForCall(0)

			Expect(createOpts.NetworkID).To(ContainSubstring("the_net_id_1"))
			Expect(createOpts.FixedIPs.([]ports.IP)[0].IPAddress).To(Equal("1.1.1.1"))
			Expect(createOpts.AllowedAddressPairs[0].IPAddress).To(Equal("allowed-address-pairs"))
		})

		It("logs that if initial port creation fails", func() {
			networkingFacade.CreatePortReturns(nil, errors.New("boom"))

			_, _ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).
				CreatePort(defaultNetwork, securityGroups, cloudProperties)

			tag, msg, _ := logger.WarnArgsForCall(0)

			Expect(tag).To(Equal("network-service"))
			Expect(msg).To(ContainSubstring("failed to create port on network 'the_net_id_1' for ip '1.1.1.1': boom"))
		})

		It("lists potentially conflicting ports", func() {
			networkingFacade.CreatePortReturns(nil, errors.New("boom"))

			_, _ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).
				CreatePort(defaultNetwork, securityGroups, cloudProperties)

			_, listOpts := networkingFacade.ListPortsArgsForCall(1)

			Expect(listOpts.NetworkID).To(Equal("the_net_id_1"))
			Expect(listOpts.FixedIPs[0].IPAddress).To(Equal("1.1.1.1"))
		})

		It("returns an error if lists potentially conflicting ports fails", func() {
			networkingFacade.CreatePortReturns(nil, errors.New("boom"))
			networkingFacade.ListPortsReturnsOnCall(0, nil, errors.New("boom"))

			_, err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).
				CreatePort(defaultNetwork, securityGroups, properties.CreateVM{})

			Expect(err.Error()).To(Equal("failed to list Ports: boom"))
		})

		It("extracts potentially conflicting ports", func() {
			networkingFacade.CreatePortReturnsOnCall(0, nil, errors.New("boom"))

			_, _ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).
				CreatePort(defaultNetwork, securityGroups, properties.CreateVM{})

			Expect(networkingFacade.ExtractPortsCallCount()).To(Equal(1))
		})

		It("returns an error if extracting potentially conflicting ports fails", func() {
			networkingFacade.CreatePortReturnsOnCall(0, nil, errors.New("boom"))
			networkingFacade.ExtractPortsReturns(nil, errors.New("boom"))

			_, err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).
				CreatePort(defaultNetwork, securityGroups, properties.CreateVM{})

			Expect(err.Error()).To(Equal("failed to extract ports: boom"))
		})

		It("deletes a conflicting ports", func() {
			networkingFacade.CreatePortReturnsOnCall(0, nil, errors.New("boom"))
			networkingFacade.ExtractPortsReturns(
				[]ports.Port{
					{ID: "the-port-id-1", Status: "DOWN", FixedIPs: []ports.IP{{IPAddress: "9.9.9.9"}}},
					{ID: "the-port-id-2", Status: "DOWN", FixedIPs: []ports.IP{{IPAddress: "9.9.9.9"}}},
				}, nil)

			_, _ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).
				CreatePort(defaultNetwork, securityGroups, properties.CreateVM{})

			Expect(networkingFacade.DeletePortCallCount()).To(Equal(2))
			_, portID := networkingFacade.DeletePortArgsForCall(0)
			Expect(portID).To(Equal("the-port-id-1"))
			_, portID = networkingFacade.DeletePortArgsForCall(1)
			Expect(portID).To(Equal("the-port-id-2"))
		})

		It("skips deleting conflicting ports, if they are used", func() {
			networkingFacade.CreatePortReturnsOnCall(0, nil, errors.New("boom"))
			networkingFacade.ExtractPortsReturns(
				[]ports.Port{
					{ID: "the-port-id-1", Status: "DOWN", FixedIPs: []ports.IP{{IPAddress: "9.9.9.9"}}},
					{ID: "the-port-id-2", Status: "UP", FixedIPs: []ports.IP{{IPAddress: "9.9.9.9"}}},
				}, nil)

			_, _ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).
				CreatePort(defaultNetwork, securityGroups, properties.CreateVM{})

			Expect(networkingFacade.DeletePortCallCount()).To(Equal(1))
			_, portID := networkingFacade.DeletePortArgsForCall(0)
			Expect(portID).To(Equal("the-port-id-1"))
		})

		It("retries the port creation", func() {
			networkingFacade.CreatePortReturnsOnCall(0, nil, errors.New("boom"))
			networkingFacade.ExtractPortsReturns(
				[]ports.Port{
					{ID: "the-port-id-1", Status: "DOWN", FixedIPs: []ports.IP{{IPAddress: "9.9.9.9"}}},
				}, nil)

			_, _ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).
				CreatePort(defaultNetwork, securityGroups, properties.CreateVM{})

			Expect(networkingFacade.CreatePortCallCount()).To(Equal(2))
		})

		It("returns an error if the second port creation fails as well", func() {
			networkingFacade.CreatePortReturnsOnCall(0, nil, errors.New("boom"))
			networkingFacade.CreatePortReturnsOnCall(1, nil, errors.New("boom"))
			networkingFacade.ExtractPortsReturns(
				[]ports.Port{
					{ID: "the-port-id-1", Status: "DOWN", FixedIPs: []ports.IP{{IPAddress: "1.1.1.1"}}},
				}, nil)

			_, err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).
				CreatePort(defaultNetwork, securityGroups, properties.CreateVM{})

			Expect(err.Error()).To(Equal("failed to recreate port on network 'the_net_id_1' for ip '1.1.1.1' boom"))
		})

		It("returns the created port", func() {
			port, err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).
				CreatePort(defaultNetwork, securityGroups, properties.CreateVM{})

			Expect(err).To(Not(HaveOccurred()))
			Expect(port.ID).To(Equal(createdPort.ID))
		})
	})

	Context("GetPorts", func() {

		It("serviceClient is retryable", func() {
			_, _ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).GetPorts("123-456", networkConfig.DefaultNetwork, true)

			serviceClient, _ := networkingFacade.ListPortsArgsForCall(0)

			Expect(serviceClient).To(BeAssignableToTypeOf(utilsRetryableServiceClient))
		})

		It("serviceClient is not retryable", func() {
			_, _ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).GetPorts("123-456", networkConfig.DefaultNetwork, false)

			serviceClient, _ := networkingFacade.ListPortsArgsForCall(0)

			Expect(serviceClient).To(BeAssignableToTypeOf(utilsRetryableServiceClient))
		})

		It("lists ports", func() {
			_, _ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).GetPorts("123-456", networkConfig.DefaultNetwork, false)

			_, listOpts := networkingFacade.ListPortsArgsForCall(0)
			Expect(listOpts.DeviceID).To(Equal("123-456"))
			Expect(listOpts.NetworkID).To(Equal("the_net_id_1"))
		})

		It("returns an error if port listing fails", func() {
			networkingFacade.ListPortsReturns(nil, errors.New("boom"))

			_, err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).GetPorts("123-456", networkConfig.DefaultNetwork, false)
			Expect(err.Error()).To(Equal("failed to list ports: boom"))
		})

		It("extracts ports", func() {
			_, _ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).GetPorts("123-456", networkConfig.DefaultNetwork, false)

			pages := networkingFacade.ExtractPortsArgsForCall(0)
			Expect(pages).To(Equal(portPage))
		})

		It("returns an error if ports cannot be extracted from pages", func() {
			networkingFacade.ExtractPortsReturns(nil, errors.New("boom"))

			_, err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).GetPorts("123-456", networkConfig.DefaultNetwork, false)
			Expect(err.Error()).To(Equal("failed to extract ports: boom"))
		})
	})

	Context("DeletePorts", func() {

		var ports = []ports.Port{{ID: "test"}}

		It("serviceClient is retryable", func() {
			_ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).DeletePorts(ports)
			serviceClient, _ := networkingFacade.DeletePortArgsForCall(0)

			Expect(serviceClient).To(BeAssignableToTypeOf(utilsRetryableServiceClient))
		})

		It("deletes the port with the correct ID", func() {
			_ = network.NewNetworkService(serviceClients, &networkingFacade, &logger).DeletePorts(ports)
			_, act := networkingFacade.DeletePortArgsForCall(0)

			Expect(act).To(Equal("test"))
		})

		It("returns an error while deleting a port", func() {
			networkingFacade.DeletePortReturns(errors.New("boom"))

			err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).DeletePorts(ports)
			Expect(err.Error()).To(Equal("failed to delete port: boom"))
		})

		It("returns nil, ports were deleted", func() {
			err := network.NewNetworkService(serviceClients, &networkingFacade, &logger).DeletePorts(ports)

			Expect(err).ToNot(HaveOccurred())
		})
	})
})
