package properties_test

import (
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("NetworkConfig", func() {

	Context("AllNetworks", func() {

		var manualNetwork1 properties.Network
		var manualNetwork2 properties.Network
		var vipNetwork *properties.Network
		var dynamicNetwork *properties.Network

		BeforeEach(func() {
			manualNetwork1 = properties.Network{Type: "manual", Key: "1"}
			manualNetwork2 = properties.Network{Type: "manual", Key: "2"}
			vipNetwork = &properties.Network{Type: "vip", Key: "3"}
			dynamicNetwork = &properties.Network{Type: "dynamic", Key: "4"}
		})

		It("returns a list of manual, dynamic and vip networks", func() {
			networkConfig := properties.NetworkConfig{
				ManualNetworks: []properties.Network{manualNetwork1, manualNetwork2},
				VIPNetwork:     vipNetwork,
				DynamicNetwork: dynamicNetwork,
			}

			Expect(networkConfig.AllNetworks()).To(ContainElements(manualNetwork1, manualNetwork2, *vipNetwork, *dynamicNetwork))
		})

		It("skips adding dynamic network, if not defined", func() {
			networkConfig := properties.NetworkConfig{
				ManualNetworks: []properties.Network{manualNetwork1, manualNetwork2},
				VIPNetwork:     vipNetwork,
			}

			Expect(networkConfig.AllNetworks()).To(ContainElements(manualNetwork1, manualNetwork2, *vipNetwork))
		})

		It("skips adding vip network, if not defined", func() {
			networkConfig := properties.NetworkConfig{
				ManualNetworks: []properties.Network{manualNetwork1, manualNetwork2},
				DynamicNetwork: dynamicNetwork,
			}

			Expect(networkConfig.AllNetworks()).To(ContainElements(manualNetwork1, manualNetwork2, *dynamicNetwork))
		})
	})
})
