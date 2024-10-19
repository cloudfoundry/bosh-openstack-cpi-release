package openstack_test

import (
	"errors"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/openstack"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/openstack/openstackfakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	"github.com/gophercloud/gophercloud"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("OpenstackService", func() {
	var openstackFacade openstackfakes.FakeOpenstackFacade
	var serviceClient gophercloud.ServiceClient
	var envVar utilsfakes.FakeEnvVar

	BeforeEach(func() {
		openstackFacade = openstackfakes.FakeOpenstackFacade{}
		serviceClient = gophercloud.ServiceClient{}
		envVar = utilsfakes.FakeEnvVar{}

		openstackFacade.AuthenticatedClientReturns(&gophercloud.ProviderClient{}, nil)
		openstackFacade.NewImageServiceV2Returns(&serviceClient, nil)
		openstackFacade.NewComputeV2Returns(&serviceClient, nil)
		openstackFacade.NewNetworkV2Returns(&serviceClient, nil)
		openstackFacade.NewLoadBalancerV2Returns(&serviceClient, nil)

		envVar.GetReturns("the_os_region_name")
	})

	Context("ImageServiceV2", func() {
		It("returns a ImageServiceV2 instance", func() {
			client, err := openstack.NewOpenstackService(&openstackFacade, &envVar).ImageServiceV2(config.OpenstackConfig{})

			Expect(err).ToNot(HaveOccurred())
			Expect(client).To(Equal(&serviceClient))
		})

		It("authenticates using the cpi config", func() {
			openstackConfig := config.OpenstackConfig{
				AuthURL:     "the_auth_url",
				Username:    "the_username",
				APIKey:      "the_api_key",
				DomainName:  "the_domain_name",
				ProjectName: "the_tenant",
			}

			_, _ = openstack.NewOpenstackService(&openstackFacade, &envVar).ImageServiceV2(openstackConfig)

			opts := openstackFacade.AuthenticatedClientArgsForCall(0)
			Expect(opts).To(Equal(gophercloud.AuthOptions{
				IdentityEndpoint: "the_auth_url",
				Username:         "the_username",
				Password:         "the_api_key",
				DomainName:       "the_domain_name",
				TenantName:       "the_tenant",
			}))
		})

		It("gets the region of the service from the environment", func() {
			_, _ = openstack.NewOpenstackService(&openstackFacade, &envVar).ImageServiceV2(config.OpenstackConfig{})

			_, endpointOpts := openstackFacade.NewImageServiceV2ArgsForCall(0)
			Expect(endpointOpts).To(Equal(gophercloud.EndpointOpts{
				Region: "the_os_region_name",
			}))
		})

		It("returns an error on failing authentication", func() {
			openstackFacade.AuthenticatedClientReturns(nil, errors.New("boom"))

			client, err := openstack.NewOpenstackService(&openstackFacade, &envVar).ImageServiceV2(config.OpenstackConfig{})

			Expect(err.Error()).To(Equal("failed to authenticate: boom"))
			Expect(client).To(BeNil())
		})

	})

	Context("ComputeServiceV2", func() {
		It("returns a ComputeServiceV2 instance", func() {
			client, err := openstack.NewOpenstackService(&openstackFacade, &envVar).ComputeServiceV2(config.OpenstackConfig{})

			Expect(err).ToNot(HaveOccurred())
			Expect(client).To(Equal(&serviceClient))
		})

		It("authenticates using the cpi config", func() {
			openstackConfig := config.OpenstackConfig{
				AuthURL:     "the_auth_url",
				Username:    "the_username",
				APIKey:      "the_api_key",
				DomainName:  "the_domain_name",
				ProjectName: "the_tenant",
			}

			_, _ = openstack.NewOpenstackService(&openstackFacade, &envVar).ComputeServiceV2(openstackConfig)

			opts := openstackFacade.AuthenticatedClientArgsForCall(0)
			Expect(opts).To(Equal(gophercloud.AuthOptions{
				IdentityEndpoint: "the_auth_url",
				Username:         "the_username",
				Password:         "the_api_key",
				DomainName:       "the_domain_name",
				TenantName:       "the_tenant",
			}))
		})

		It("gets the region of the service from the environment", func() {
			_, _ = openstack.NewOpenstackService(&openstackFacade, &envVar).ComputeServiceV2(config.OpenstackConfig{})

			_, endpointOpts := openstackFacade.NewComputeV2ArgsForCall(0)
			Expect(endpointOpts).To(Equal(gophercloud.EndpointOpts{
				Region: "the_os_region_name",
			}))
		})

		It("returns an error on failing authentication", func() {
			openstackFacade.AuthenticatedClientReturns(nil, errors.New("boom"))

			client, err := openstack.NewOpenstackService(&openstackFacade, &envVar).ComputeServiceV2(config.OpenstackConfig{})

			Expect(err.Error()).To(Equal("failed to authenticate: boom"))
			Expect(client).To(BeNil())
		})

	})

	Context("LoadbalancerServiceV2", func() {
		It("returns a LoadbalancerV2 instance", func() {
			client, err := openstack.NewOpenstackService(&openstackFacade, &envVar).LoadbalancerV2(config.OpenstackConfig{})

			Expect(err).ToNot(HaveOccurred())
			Expect(client).To(Equal(&serviceClient))
		})

		It("authenticates using the cpi config", func() {
			openstackConfig := config.OpenstackConfig{
				AuthURL:     "the_auth_url",
				Username:    "the_username",
				APIKey:      "the_api_key",
				DomainName:  "the_domain_name",
				ProjectName: "the_tenant",
			}

			_, _ = openstack.NewOpenstackService(&openstackFacade, &envVar).LoadbalancerV2(openstackConfig)

			opts := openstackFacade.AuthenticatedClientArgsForCall(0)
			Expect(opts).To(Equal(gophercloud.AuthOptions{
				IdentityEndpoint: "the_auth_url",
				Username:         "the_username",
				Password:         "the_api_key",
				DomainName:       "the_domain_name",
				TenantName:       "the_tenant",
			}))
		})

		It("gets the region of the service from the environment", func() {
			_, _ = openstack.NewOpenstackService(&openstackFacade, &envVar).LoadbalancerV2(config.OpenstackConfig{})

			_, endpointOpts := openstackFacade.NewLoadBalancerV2ArgsForCall(0)
			Expect(endpointOpts).To(Equal(gophercloud.EndpointOpts{
				Region: "the_os_region_name",
			}))
		})

		It("returns an error on failing authentication", func() {
			openstackFacade.AuthenticatedClientReturns(nil, errors.New("boom"))

			client, err := openstack.NewOpenstackService(&openstackFacade, &envVar).LoadbalancerV2(config.OpenstackConfig{})

			Expect(err.Error()).To(Equal("failed to authenticate: boom"))
			Expect(client).To(BeNil())
		})

	})

	Context("NetworkServiceV2", func() {
		It("returns a NetworkServiceV2 instance", func() {
			client, err := openstack.NewOpenstackService(&openstackFacade, &envVar).NetworkServiceV2(config.OpenstackConfig{})

			Expect(err).ToNot(HaveOccurred())
			Expect(client).To(Equal(&serviceClient))
		})

		It("authenticates using the cpi config", func() {
			openstackConfig := config.OpenstackConfig{
				AuthURL:     "the_auth_url",
				Username:    "the_username",
				APIKey:      "the_api_key",
				DomainName:  "the_domain_name",
				ProjectName: "the_tenant",
			}

			_, _ = openstack.NewOpenstackService(&openstackFacade, &envVar).NetworkServiceV2(openstackConfig)

			opts := openstackFacade.AuthenticatedClientArgsForCall(0)
			Expect(opts).To(Equal(gophercloud.AuthOptions{
				IdentityEndpoint: "the_auth_url",
				Username:         "the_username",
				Password:         "the_api_key",
				DomainName:       "the_domain_name",
				TenantName:       "the_tenant",
			}))
		})

		It("gets the region of the service from the environment", func() {
			_, _ = openstack.NewOpenstackService(&openstackFacade, &envVar).NetworkServiceV2(config.OpenstackConfig{})

			_, endpointOpts := openstackFacade.NewNetworkV2ArgsForCall(0)
			Expect(endpointOpts).To(Equal(gophercloud.EndpointOpts{
				Region: "the_os_region_name",
			}))
		})

		It("returns an error on failing authentication", func() {
			openstackFacade.AuthenticatedClientReturns(nil, errors.New("boom"))

			client, err := openstack.NewOpenstackService(&openstackFacade, &envVar).NetworkServiceV2(config.OpenstackConfig{})

			Expect(err.Error()).To(Equal("failed to authenticate: boom"))
			Expect(client).To(BeNil())
		})

	})
})
