package bats_test

import (
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"bosh-openstack-cpi-release/ci/bats/helpers"
)

var _ = Describe("Manual networking", func() {
	const deployment = "bats-networking"

	AfterEach(func() {
		_ = bosh.DeleteDeployment(deployment)
	})

	It("assigns the expected static IP on the primary manual network", func() {
		primary := cfg.PrimaryNetwork()
		manifest := helpers.VMLifecycleManifest(cfg, deployment, primary.StaticIP)

		f, err := os.CreateTemp("", "bats-net-manifest-*.yml")
		Expect(err).NotTo(HaveOccurred())
		defer os.Remove(f.Name())
		_, err = f.WriteString(manifest)
		Expect(err).NotTo(HaveOccurred())
		Expect(f.Close()).To(Succeed())

		By("deploying")
		_, err = bosh.Deploy(f.Name())
		Expect(err).NotTo(HaveOccurred())

		By("verifying the instance IP matches the requested static IP")
		instances, err := bosh.Instances(deployment)
		Expect(err).NotTo(HaveOccurred())
		Expect(instances).To(HaveLen(1))
		Expect(instances[0].IPs).To(ContainSubstring(primary.StaticIP),
			"instance IP should contain the requested static IP %s", primary.StaticIP)
	})

	It("deploys two VMs on separate manual networks", func() {
		secondary, ok := cfg.SecondaryNetwork()
		if !ok {
			Skip("no secondary network configured in BAT_DEPLOYMENT_SPEC")
		}

		primary := cfg.PrimaryNetwork()
		manifest := helpers.MultiNetworkManifest(cfg, deployment,
			primary.StaticIP, secondary.StaticIP)

		f, err := os.CreateTemp("", "bats-multinetwork-*.yml")
		Expect(err).NotTo(HaveOccurred())
		defer os.Remove(f.Name())
		_, err = f.WriteString(manifest)
		Expect(err).NotTo(HaveOccurred())
		Expect(f.Close()).To(Succeed())

		By("deploying two instance groups across two networks")
		_, err = bosh.Deploy(f.Name())
		Expect(err).NotTo(HaveOccurred())

		By("verifying both instances are running")
		instances, err := bosh.Instances(deployment)
		Expect(err).NotTo(HaveOccurred())
		Expect(instances).To(HaveLen(2))
		for _, inst := range instances {
			Expect(inst.State).To(Equal("running"))
		}
	})
})
