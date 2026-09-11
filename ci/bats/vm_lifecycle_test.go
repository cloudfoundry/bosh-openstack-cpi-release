package bats_test

import (
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"bosh-openstack-cpi-release/ci/bats/helpers"
)

var _ = Describe("VM lifecycle", func() {
	const deployment = "bats-vm-lifecycle"

	AfterEach(func() {
		// Best-effort cleanup so a failed test does not leave orphaned VMs.
		_ = bosh.DeleteDeployment(deployment)
	})

	It("deploys a VM and deletes the deployment", func() {
		primary := cfg.PrimaryNetwork()
		manifest := helpers.VMLifecycleManifest(cfg, deployment, primary.StaticIP)

		f, err := os.CreateTemp("", "bats-manifest-*.yml")
		Expect(err).NotTo(HaveOccurred())
		defer os.Remove(f.Name())
		_, err = f.WriteString(manifest)
		Expect(err).NotTo(HaveOccurred())
		Expect(f.Close()).To(Succeed())

		By("deploying")
		_, err = bosh.Deploy(f.Name())
		Expect(err).NotTo(HaveOccurred())

		By("confirming instance is running")
		instances, err := bosh.Instances(deployment)
		Expect(err).NotTo(HaveOccurred())
		Expect(instances).To(HaveLen(1))
		Expect(instances[0].State).To(Equal("running"))

		By("deleting deployment")
		Expect(bosh.DeleteDeployment(deployment)).To(Succeed())
	})
})
