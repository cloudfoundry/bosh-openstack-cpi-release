package cpi

import (
	"fmt"

	"github.com/cloudfoundry/bosh-cpi-go/rpc"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	boshlog "github.com/cloudfoundry/bosh-utils/logger"
)

func Execute(cpiConfig config.CpiConfig, cpiLogger boshlog.Logger) error {

	cli := rpc.NewFactory(cpiLogger).NewCLI(
		NewFactory(cpiConfig, cpiLogger),
	)

	err := cli.ServeOnce()
	if err != nil {
		return fmt.Errorf("failed to serve the request %w", err)
	}

	return nil
}
