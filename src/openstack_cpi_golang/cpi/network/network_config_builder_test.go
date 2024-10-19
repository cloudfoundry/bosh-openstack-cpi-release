package network_test

import (
	"encoding/binary"
	"encoding/json"
	"net"
	"sort"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/network"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/network/networkfakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("NetworkConfigBuilder", func() {
	var networkingConfig properties.NetworkConfig
	var securityGroupsResolver networkfakes.FakeSecurityGroupsResolver
	var openstackConfig config.OpenstackConfig
	var cloudProperties properties.CreateVM
	var logger utils.Logger

	BeforeEach(func() {
		openstackConfig = config.OpenstackConfig{}
		cloudProperties = properties.CreateVM{}
		securityGroupsResolver = networkfakes.FakeSecurityGroupsResolver{}
		logger = &utilsfakes.FakeLogger{}
	})

	Context("NewNetworkConfig", func() {
		BeforeEach(func() {
			networkingConfig, _ = createNetworkConfig(&securityGroupsResolver, []byte(`{
				"name1": {
					"type":    "manual",
					"ip":      "1.1.1.1",
					"default": ["gateway"],
					"cloud_properties": {"net_id": "the_net_id_1", "security_groups": ["security_group_1", "security_group_2"]}
				},
				"name2": {
					"type":    "manual",
					"ip":      "2.2.2.2",
					"cloud_properties": {"net_id": "the_net_id_2"}
				},
				"name3": {
					"type":    "vip",
					"ip":      "3.3.3.3",
					"cloud_properties": {"net_id": "the_net_id_3", "security_groups": ["security_group_3"]}
				},
				"name4": {
					"type":    "dynamic",
					"ip":      "4.4.4.4",
					"cloud_properties": {"net_id": "the_net_id_4", "security_groups": ["security_group_4"]}
				}
			}`), openstackConfig, cloudProperties, logger)
		})

		It("returns an error if a manual network is missing a netid", func() {
			_, err := createNetworkConfig(&securityGroupsResolver, []byte(`{
				"name1": {
					"type":    "manual",
					"ip":      "",
					"cloud_properties": {"missing_net_id": ""}
				},
				"name2": {
					"type":    "manual",
					"ip":      "",
					"cloud_properties": {"net_id": "the_net_id_2"}
				}
			}`), openstackConfig, cloudProperties, logger)

			Expect(err.Error()).To(Equal("invalid manual network configuration: manual network must have a net_id"))
		})

		It("returns an error if multiple manual network exists while dhcp should be used and config drive is not defined", func() {
			_, err := createNetworkConfig(&securityGroupsResolver, []byte(`{
				"name1": {
					"type":    "manual",
					"ip":      "",
					"cloud_properties": {"net_id": "the_net_id_1"}
				},
				"name2": {
					"type":    "manual",
					"ip":      "",
					"cloud_properties": {"net_id": "the_net_id_2"}
				}
			}`), config.OpenstackConfig{UseDHCP: true}, cloudProperties, logger)

			Expect(err.Error()).To(Equal("invalid manual network configuration: multiple manual networks can only be used with 'openstack.use_dhcp=false' and 'openstack.config_drive=cdrom|disk'"))
		})

		It("returns an error if multiple vip networks exists", func() {
			_, err := createNetworkConfig(&securityGroupsResolver, []byte(`{
				"name1": {
					"type":    "vip",
					"ip":      "",
					"cloud_properties": {}
				},
				"name2": {
					"type":    "vip",
					"ip":      "",
					"cloud_properties": {}
				}
			}`), openstackConfig, cloudProperties, logger)

			Expect(err.Error()).To(Equal("invalid vip network configuration: only one vip should be defined per instance"))
		})

		It("returns an error if multiple dynamic networks exists", func() {
			_, err := createNetworkConfig(&securityGroupsResolver, []byte(`{
				"name1": {
					"type":    "dynamic",
					"ip":      "",
					"cloud_properties": {}
				},
				"name2": {
					"type":    "dynamic",
					"ip":      "",
					"cloud_properties": {}
				}
			}`), openstackConfig, cloudProperties, logger)

			Expect(err.Error()).To(Equal("invalid dynamic network configuration: only one dynamic should be defined per instance"))
		})

		It("returns an error if same net_id is used by multiple networks", func() {
			_, err := createNetworkConfig(&securityGroupsResolver, []byte(`{
				"name1": {
					"type":    "manual",
					"ip":      "",
					"cloud_properties": {"net_id": "same_net_id"}
				},
				"name2": {
					"type":    "dynamic",
					"ip":      "",
					"cloud_properties": {"net_id": "same_net_id"}
				}
			}`), openstackConfig, cloudProperties, logger)

			Expect(err.Error()).To(Equal("invalid network configuration: network with id same_net_id is defined multiple times"))
		})
	})

	Context("DefaultNetwork", func() {
		It("returns the default network", func() {
			defaultNetwork := networkingConfig.DefaultNetwork

			Expect(defaultNetwork.Type).To(Equal("manual"))
			Expect(defaultNetwork.IP).To(Equal("1.1.1.1"))
			Expect(defaultNetwork.CloudProps.NetID).To(Equal("the_net_id_1"))
		})

		It("returns an empty network if no network is provided", func() {
			networkingConfig, err := createNetworkConfig(&securityGroupsResolver, []byte(`{}`), openstackConfig, cloudProperties, logger)
			Expect(err).ToNot(HaveOccurred())
			defaultNetwork := networkingConfig.DefaultNetwork

			Expect(defaultNetwork.Type).To(Equal(""))
			Expect(defaultNetwork.IP).To(Equal(""))
			Expect(defaultNetwork.CloudProps.NetID).To(Equal(""))
		})
	})

	Context("GetManualNetworks", func() {
		It("returns the manual networks", func() {
			manualNetworks := sortNetworks(networkingConfig.ManualNetworks)

			Expect(manualNetworks[0].Type).To(Equal("manual"))
			Expect(manualNetworks[0].IP).To(Equal("1.1.1.1"))
			Expect(manualNetworks[0].CloudProps.NetID).To(Equal("the_net_id_1"))

			Expect(manualNetworks[1].Type).To(Equal("manual"))
			Expect(manualNetworks[1].IP).To(Equal("2.2.2.2"))
			Expect(manualNetworks[1].CloudProps.NetID).To(Equal("the_net_id_2"))
		})
	})

	Context("GetVIPNetwork", func() {
		It("returns the vip network", func() {
			vipNetwork := networkingConfig.VIPNetwork

			Expect(vipNetwork.Type).To(Equal("vip"))
			Expect(vipNetwork.IP).To(Equal("3.3.3.3"))
			Expect(vipNetwork.CloudProps.NetID).To(Equal("the_net_id_3"))
		})
	})

	Context("GetDynamicNetwork", func() {
		It("returns the dynamic network", func() {
			dynamicNetwork := networkingConfig.DynamicNetwork

			Expect(dynamicNetwork.Type).To(Equal("dynamic"))
			Expect(dynamicNetwork.IP).To(Equal("4.4.4.4"))
			Expect(dynamicNetwork.CloudProps.NetID).To(Equal("the_net_id_4"))
		})
	})

	Context("SecurityGroups", func() {
		It("returns cloud properties security groups", func() {
			securityGroupsResolver.ResolveReturns([]string{"resolved_security_group_1", "resolved_security_group_2"}, nil)

			networkingConfig, _ = createNetworkConfig(&securityGroupsResolver, []byte(`{
					"name1": {
						"type":    "manual",
						"ip":      "1.1.1.1",
						"default": ["gateway"],
						"cloud_properties": {"net_id": "the_net_id_1", "security_groups": ["security_group_1", "security_group_2"]}
					}
				}`),
				config.OpenstackConfig{
					DefaultSecurityGroups: []string{"default_security_group_1", "default_security_group_2"},
				},
				properties.CreateVM{
					SecurityGroups: []string{"cloud_config_security_group_1", "cloud_config_security_group_2"},
				}, logger)
			securityGroups := networkingConfig.SecurityGroups

			securityGroupsParam := securityGroupsResolver.ResolveArgsForCall(0)
			Expect(securityGroupsParam).To(ContainElements("cloud_config_security_group_1", "cloud_config_security_group_2"))
			Expect(securityGroups).To(ContainElements("resolved_security_group_1", "resolved_security_group_2"))
		})

		It("returns network security groups if cloud properties do not define security groups", func() {
			securityGroupsResolver.ResolveReturns([]string{"resolved_network_security_group_1", "resolved_network_security_group_2"}, nil)

			networkingConfig, _ = createNetworkConfig(&securityGroupsResolver, []byte(`{
					"name1": {
						"type":    "manual",
						"ip":      "1.1.1.1",
						"default": ["gateway"],
						"cloud_properties": {"net_id": "the_net_id_1", "security_groups": ["security_group_1", "security_group_2"]}
					}
				}`),
				config.OpenstackConfig{
					DefaultSecurityGroups: []string{"default_security_group_1", "default_security_group_2"},
				},
				properties.CreateVM{},
				logger,
			)
			securityGroups := networkingConfig.SecurityGroups

			securityGroupsParam := securityGroupsResolver.ResolveArgsForCall(0)
			Expect(securityGroupsParam).To(ContainElements("security_group_1", "security_group_2"))
			Expect(securityGroups).To(ContainElements("resolved_network_security_group_1", "resolved_network_security_group_2"))
		})

		It("returns default security groups if network security groups are not defined", func() {
			securityGroupsResolver.ResolveReturns([]string{"resolved_default_group_1", "resolved_default_group_2"}, nil)

			networkingConfig, _ = createNetworkConfig(&securityGroupsResolver, []byte(`{
					"name1": {
						"type":    "manual",
						"ip":      "1.1.1.1",
						"default": ["gateway"],
						"cloud_properties": {"net_id": "the_net_id_1", "security_groups": ["security_group_1", "security_group_2"]}
					}
				}`),
				config.OpenstackConfig{
					DefaultSecurityGroups: []string{"default_security_group_1", "default_security_group_2"},
				},
				properties.CreateVM{},
				logger,
			)
			securityGroups := networkingConfig.SecurityGroups

			securityGroupsParam := securityGroupsResolver.ResolveArgsForCall(0)
			Expect(securityGroupsParam).To(ContainElements("security_group_1", "security_group_2"))
			Expect(securityGroups).To(ContainElements("resolved_default_group_1", "resolved_default_group_2"))
		})

		It("network security groups merge all networks", func() {
			securityGroupsResolver.ResolveReturns([]string{
				"resolved_security_group_1", "resolved_security_group_2", "resolved_security_group_3", "resolved_security_group_4",
			}, nil)

			networkingConfig, _ = createNetworkConfig(&securityGroupsResolver, []byte(`{
				"name1": {
					"type":    "manual",
					"ip":      "1.1.1.1",
					"default": ["gateway"],
					"cloud_properties": {"net_id": "the_net_id_1", "security_groups": ["security_group_1", "security_group_2"]}
				},
				"name2": {
					"type":    "manual",
					"ip":      "2.2.2.2",
					"cloud_properties": {"net_id": "the_net_id_2"}
				},
				"name3": {
					"type":    "vip",
					"ip":      "3.3.3.3",
					"cloud_properties": {"net_id": "the_net_id_3", "security_groups": ["security_group_3"]}
				},
				"name4": {
					"type":    "dynamic",
					"ip":      "4.4.4.4",
					"cloud_properties": {"net_id": "the_net_id_4", "security_groups": ["security_group_4"]}
				}
			}`), openstackConfig, cloudProperties, logger)
			securityGroups := sortSecurityGroups(networkingConfig.SecurityGroups)

			securityGroupsParam := securityGroupsResolver.ResolveArgsForCall(0)
			Expect(securityGroupsParam).To(ContainElements("security_group_1", "security_group_2", "security_group_4", "security_group_3"))
			Expect(securityGroups).To(ContainElements("resolved_security_group_1", "resolved_security_group_2", "resolved_security_group_3", "resolved_security_group_4"))
		})
	})
})

func createNetworkConfig(securityGroupsResolver network.SecurityGroupsResolver, bytes []byte, openstackConfig config.OpenstackConfig, cloudProperties properties.CreateVM, logger utils.Logger) (properties.NetworkConfig, error) {
	var networks apiv1.Networks
	err := json.Unmarshal(bytes, &networks)
	Expect(err).ToNot(HaveOccurred())

	networkConfig, err := network.NewNetworkConfigBuilder(securityGroupsResolver, networks, openstackConfig, cloudProperties, logger).Build()

	return networkConfig, err
}

func sortSecurityGroups(securityGroups []string) []string {
	sort.Slice(securityGroups, func(i, j int) bool {
		return securityGroups[i] < securityGroups[j]
	})

	return securityGroups
}

func sortNetworks(networks []properties.Network) []properties.Network {
	sort.Slice(networks, func(i, j int) bool {
		return ip2int(net.ParseIP(networks[i].IP)) < ip2int(net.ParseIP(networks[j].IP))
	})

	return networks
}

func ip2int(ip net.IP) uint32 {
	if len(ip) == 16 {
		return binary.BigEndian.Uint32(ip[12:16])
	}
	return binary.BigEndian.Uint32(ip)
}
