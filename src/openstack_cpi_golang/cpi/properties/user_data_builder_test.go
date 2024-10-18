package properties_test

import (
	"encoding/json"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("userDataBuilder", func() {

	var _ = Context("WithServer", func() {
		It("sets server data", func() {
			userData := properties.NewUserDataBuilder().WithServer(properties.Server{Name: "the-name"}).Build()

			Expect(userData.Server).To(Equal(properties.Server{Name: "the-name"}))
		})
	})

	var _ = Context("WithServer", func() {
		It("sets network data", func() {
			userDataNetwork := map[string]properties.UserdataNetwork{}
			userDataNetwork["bosh"] = properties.UserdataNetwork{IP: "1.1.1.1"}
			userData := properties.NewUserDataBuilder().WithNetworks(userDataNetwork).Build()

			Expect(userData.Networks).To(Equal(userDataNetwork))
		})

		It("it sets dns data", func() {
			userDataNetwork := map[string]properties.UserdataNetwork{}
			userDataNetwork["bosh"] = properties.UserdataNetwork{IP: "1.1.1.1"}
			userData := properties.NewUserDataBuilder().WithNetworks(userDataNetwork).Build()

			Expect(userData.Networks).To(Equal(userDataNetwork))
		})
	})

	var _ = Context("WithConfig", func() {
		It("sets vm data", func() {
			cpiConfig := config.CpiConfig{}
			cpiConfig.Cloud.Properties.Agent.MBus = "the-mbus"

			userData := properties.NewUserDataBuilder().WithConfig(cpiConfig).Build()

			Expect(userData.MBus).To(Equal("the-mbus"))
		})
	})

	var _ = Context("WithVM", func() {
		It("sets vm data", func() {
			userData := properties.NewUserDataBuilder().WithVM(properties.VM{Name: "the-name"}).Build()

			Expect(userData.VM).To(Equal(properties.VM{Name: "the-name"}))
		})
	})

	var _ = Context("WithEphemeralDiskSize", func() {
		It("sets ephemeral disk data", func() {
			userData := properties.NewUserDataBuilder().WithEphemeralDiskSize(1).Build()

			Expect(userData.Disks).To(Equal(properties.Disks{System: "/dev/sda", Ephemeral: "/dev/sdb"}))
		})

		It("does not set ephemeral disk data if size is 0", func() {
			userData := properties.NewUserDataBuilder().WithEphemeralDiskSize(0).Build()

			Expect(userData.Disks).To(Equal(properties.Disks{System: "/dev/sda"}))
		})
	})

	var _ = Context("WithAgentID", func() {
		It("sets the agentID", func() {
			userData := properties.NewUserDataBuilder().WithAgentID(apiv1.NewAgentID("the-agent-id")).Build()

			Expect(userData.AgentID).To(Equal("the-agent-id"))
		})
	})

	var _ = Context("WithEnvironment", func() {
		It("sets the environment", func() {
			jsonString := `{"test":{"a":"a"}}`

			userData := properties.NewUserDataBuilder().WithEnvironment([]byte(jsonString)).Build()
			data, err := json.Marshal(userData)

			Expect(err).ToNot(HaveOccurred())
			Expect(string(data)).To(ContainSubstring(jsonString))
		})
	})
})
