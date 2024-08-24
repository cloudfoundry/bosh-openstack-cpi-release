package cpi

import (
	"fmt"

	"github.com/cloudfoundry/bosh-cpi-go/rpc"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
)

func Execute(cpiConfig config.CpiConfig, cpiLogger utils.Logger) error {

	cli := rpc.NewFactory(cpiLogger.TargetLogger()).NewCLI(
		NewFactory(cpiConfig, cpiLogger),
	)

	err := cli.ServeOnce()
	if err != nil {
		return fmt.Errorf("failed to serve the request %w", err)
	}

	return nil
}
