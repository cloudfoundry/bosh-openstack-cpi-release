package bats_test

import (
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"bosh-openstack-cpi-release/ci/bats/helpers"
)

var _ = Describe("Persistent disk", func() {
	const deployment = "bats-persistent-disk"

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
		deployed = true

		By("recording disk CID before recreate")
		detailsBefore, err := bosh.InstancesDetails(deployment)
		Expect(err).NotTo(HaveOccurred())
		Expect(detailsBefore).To(HaveLen(1))
		Expect(detailsBefore[0].State).To(Equal("running"))
		diskCIDBefore := detailsBefore[0].DiskCID
		Expect(diskCIDBefore).NotTo(BeEmpty(), "instance should have a persistent disk attached")

		By("recreating the VM")
		Expect(bosh.Recreate(deployment)).To(Succeed())

		By("confirming disk CID is preserved after recreate")
		detailsAfter, err := bosh.InstancesDetails(deployment)
		Expect(err).NotTo(HaveOccurred())
		Expect(detailsAfter).To(HaveLen(1))
		Expect(detailsAfter[0].State).To(Equal("running"))
		Expect(detailsAfter[0].DiskCID).To(Equal(diskCIDBefore),
			"disk CID should be identical before and after recreate")
	})
})
