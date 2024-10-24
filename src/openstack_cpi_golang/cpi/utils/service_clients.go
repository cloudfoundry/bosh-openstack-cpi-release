package utils

import (
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/gophercloud/gophercloud"
)

type ServiceClient *gophercloud.ServiceClient
type RetryableServiceClient *gophercloud.ServiceClient

type ServiceClients struct {
	ServiceClient          ServiceClient
	RetryableServiceClient RetryableServiceClient
}

func NewServiceClients(serviceClient *gophercloud.ServiceClient, cpiConfig config.CpiConfig, logger Logger) ServiceClients {
	retryableServiceClient := serviceClient
	retryableServiceClient.RetryFunc = RetryOnError(cpiConfig.Properties().RetryConfig.Default(), logger)

	return ServiceClients{
		ServiceClient:          serviceClient,
		RetryableServiceClient: retryableServiceClient,
	}
}
