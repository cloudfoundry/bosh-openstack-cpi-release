package bats_test

import (
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"bosh-openstack-cpi-release/ci/bats/helpers"
)

var _ = Describe("SSH", func() {
	const deployment = "bats-ssh"

	AfterEach(func() {
		_ = bosh.DeleteDeployment(deployment)
	})

	It("can SSH through the jumpbox to a deployed VM", func() {
		primary := cfg.PrimaryNetwork()
		manifest := helpers.VMLifecycleManifest(cfg, deployment, primary.StaticIP)

		f, err := os.CreateTemp("", "bats-ssh-manifest-*.yml")
		Expect(err).NotTo(HaveOccurred())
		defer os.Remove(f.Name())
		_, err = f.WriteString(manifest)
		Expect(err).NotTo(HaveOccurred())
		Expect(f.Close()).To(Succeed())

		By("deploying")
		_, err = bosh.Deploy(f.Name())
		Expect(err).NotTo(HaveOccurred())

		By("SSHing to the instance and running a command")
		out, err := bosh.SSH(deployment, "bats-vm/0", "echo bats-ssh-ok")
		Expect(err).NotTo(HaveOccurred(), "bosh ssh failed: %s", out)
		Expect(out).To(ContainSubstring("bats-ssh-ok"))
	})
})
