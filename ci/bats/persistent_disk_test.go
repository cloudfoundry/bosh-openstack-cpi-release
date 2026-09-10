package bats_test

import (
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"bosh-openstack-cpi-release/ci/bats/helpers"
)

var _ = Describe("Persistent disk", func() {
	const deployment = "bats-persistent-disk"

	AfterEach(func() {
		_ = bosh.DeleteDeployment(deployment)
	})

	It("preserves the disk across a VM recreate", func() {
		primary := cfg.PrimaryNetwork()
		manifest := helpers.PersistentDiskManifest(cfg, deployment, primary.StaticIP)

		f, err := os.CreateTemp("", "bats-disk-manifest-*.yml")
		Expect(err).NotTo(HaveOccurred())
		defer os.Remove(f.Name())
		_, err = f.WriteString(manifest)
		Expect(err).NotTo(HaveOccurred())
		Expect(f.Close()).To(Succeed())

		By("deploying with persistent disk")
		_, err = bosh.Deploy(f.Name())
		Expect(err).NotTo(HaveOccurred())

		By("confirming instance is running")
		instances, err := bosh.Instances(deployment)
		Expect(err).NotTo(HaveOccurred())
		Expect(instances).To(HaveLen(1))
		Expect(instances[0].State).To(Equal("running"))

		By("recreating the VM")
		Expect(bosh.Recreate(deployment)).To(Succeed())

		By("confirming instance is still running after recreate")
		instances, err = bosh.Instances(deployment)
		Expect(err).NotTo(HaveOccurred())
		Expect(instances).To(HaveLen(1))
		Expect(instances[0].State).To(Equal("running"))
	})
})
