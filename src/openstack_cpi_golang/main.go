package main

import (
	"flag"
	"os"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	boshlog "github.com/cloudfoundry/bosh-utils/logger"
)

var (
	configPathOpt = flag.String("configFile", "", "Path to configuration file")
)

func main() {
	boshLogger := boshlog.NewWriterLogger(boshlog.LevelDebug, os.Stderr)
	cpiLogger := utils.NewLogger(boshLogger)
	fileSystem := os.DirFS("/")
	defer cpiLogger.HandlePanic("Main")

	flag.Parse()

	cpiConfig, err := config.NewConfigFromPath(fileSystem, *configPathOpt)
	if err != nil {
		cpiLogger.Error("main", "failed loading the configuration: %w", err)
		os.Exit(1)
	}
	err = cpiConfig.Validate()
	if err != nil {
		cpiLogger.Error("main", "failed validating the configuration: %w", err)
		os.Exit(1)
	}

	err = cpi.Execute(cpiConfig, cpiLogger)
	if err != nil {
		cpiLogger.Error("main", "execution failed with: %w", err)
		os.Exit(1)
	}
}
