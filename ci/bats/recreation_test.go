package bats_test

import (
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"bosh-openstack-cpi-release/ci/bats/helpers"
)

var _ = Describe("VM recreation", func() {
	const deployment = "bats-recreation"

	var deployed bool

	BeforeEach(func() {
		deployed = false
	})

	AfterEach(func() {
		if deployed {
			Expect(bosh.DeleteDeployment(deployment)).To(Succeed())
		} else {
			_ = bosh.DeleteDeployment(deployment)
		}
	})

	It("recreates the VM and brings it back with the same static IP", func() {
		primary := cfg.PrimaryNetwork()
		manifest := helpers.VMLifecycleManifest(cfg, deployment, primary.StaticIP)

		f, err := os.CreateTemp("", "bats-recreate-manifest-*.yml")
		Expect(err).NotTo(HaveOccurred())
		defer os.Remove(f.Name())
		_, err = f.WriteString(manifest)
		Expect(err).NotTo(HaveOccurred())
		Expect(f.Close()).To(Succeed())

		By("deploying")
		_, err = bosh.Deploy(f.Name())
		Expect(err).NotTo(HaveOccurred())
		deployed = true

		By("recording instance IP before recreate")
		instancesBefore, err := bosh.Instances(deployment)
		Expect(err).NotTo(HaveOccurred())
		Expect(instancesBefore).To(HaveLen(1))
		ipBefore := instancesBefore[0].IPs

		By("recreating")
		Expect(bosh.Recreate(deployment)).To(Succeed())

		By("confirming instance is running with same IP after recreate")
		instancesAfter, err := bosh.Instances(deployment)
		Expect(err).NotTo(HaveOccurred())
		Expect(instancesAfter).To(HaveLen(1))
		Expect(instancesAfter[0].State).To(Equal("running"))
		Expect(instancesAfter[0].IPs).To(Equal(ipBefore), "IP should not change across recreate")
	})
})
