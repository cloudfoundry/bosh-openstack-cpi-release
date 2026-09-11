package bats_test

import (
	"os"
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"bosh-openstack-cpi-release/ci/bats/helpers"
)

func TestBATs(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "BOSH Acceptance Tests (OpenStack)")
}

var cfg *helpers.Config
var bosh *helpers.Runner

var _ = BeforeSuite(func() {
	// Skip the full suite setup when running in dry-run mode (e.g. local syntax check).
	if os.Getenv("BAT_DIRECTOR") == "dry-run" {
		Skip("BAT_DIRECTOR=dry-run: skipping real director tests")
	}

	var err error
	cfg, err = helpers.NewConfig()
	Expect(err).NotTo(HaveOccurred(), "loading BAT config")

	bosh = helpers.NewRunner(cfg)

	By("uploading stemcell")
	Expect(bosh.UploadStemcell(cfg.StemcellPath)).To(Succeed())

	By("updating cloud config")
	f, err := os.CreateTemp("", "bats-cloud-config-*.yml")
	Expect(err).NotTo(HaveOccurred())
	defer os.Remove(f.Name())
	_, err = f.WriteString(helpers.CloudConfig(cfg))
	Expect(err).NotTo(HaveOccurred())
	Expect(f.Close()).To(Succeed())
	Expect(bosh.UpdateCloudConfig(f.Name())).To(Succeed())
})
