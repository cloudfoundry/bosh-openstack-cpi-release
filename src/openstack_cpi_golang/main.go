package main

import (
	"flag"
	"os"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	boshlog "github.com/cloudfoundry/bosh-utils/logger"
)

var (
	configPathOpt = flag.String("configFile", "", "Path to configuration file")
	caCertPathOpt = flag.String("caCert", "", "Path to ca cert file") //nolint:unused
)

func main() {
	boshLogger := boshlog.NewWriterLogger(boshlog.LevelDebug, os.Stderr)
	fileSystem := os.DirFS("/")
	defer boshLogger.HandlePanic("main")

	flag.Parse()

	cpiConfig, err := config.NewConfigFromPath(fileSystem, *configPathOpt)
	if err != nil {
		boshLogger.Error("main", "failed loading the configuration: %v", err)
		os.Exit(1)
	}
	err = cpiConfig.Validate()
	if err != nil {
		boshLogger.Error("main", "failed validating the configuration: %v", err)
		os.Exit(1)
	}

	err = cpi.Execute(cpiConfig, boshLogger)
	if err != nil {
		boshLogger.Error("main", "execution failed with: %v", err)
		os.Exit(1)
	}
}
