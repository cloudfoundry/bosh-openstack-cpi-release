package compute_test

import (
	"encoding/base64"
	"encoding/json"
	"errors"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute/computefakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/loadbalancer/loadbalancerfakes"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	"github.com/gophercloud/gophercloud"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/extensions/bootfromvolume"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/extensions/keypairs"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/flavors"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/servers"
	"github.com/gophercloud/gophercloud/openstack/networking/v2/ports"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("ComputeService", func() {
	var serviceClient gophercloud.ServiceClient
	var retryableServiceClient gophercloud.ServiceClient
	var serviceClients utils.ServiceClients
	var utilsServiceClient utils.ServiceClient
	var computeFacade computefakes.FakeComputeFacade
	var flavorResolver computefakes.FakeFlavorResolver
	var volumeConfigurator computefakes.FakeVolumeConfigurator
	var availabilityZoneProvider computefakes.FakeAvailabilityZoneProvider
	var logger utilsfakes.FakeLogger
	var computeService compute.ComputeService
	var networkConfig properties.NetworkConfig
	var defaultCloudConfig properties.CreateVM
	var loadbalancerService loadbalancerfakes.FakeLoadbalancerService
	var agentID apiv1.AgentID
	var env apiv1.VMEnv

	BeforeEach(func() {
		serviceClient = gophercloud.ServiceClient{}
		retryableServiceClient = gophercloud.ServiceClient{}
		serviceClients = utils.ServiceClients{ServiceClient: &serviceClient, RetryableServiceClient: &retryableServiceClient}
		computeFacade = computefakes.FakeComputeFacade{}
		flavorResolver = computefakes.FakeFlavorResolver{}
		volumeConfigurator = computefakes.FakeVolumeConfigurator{}
		availabilityZoneProvider = computefakes.FakeAvailabilityZoneProvider{}
		logger = utilsfakes.FakeLogger{}

		computeService = compute.NewComputeService(serviceClients, &computeFacade, &flavorResolver, &volumeConfigurator, &availabilityZoneProvider, &logger)
		compute.ComputeServicePollingInterval = 0
		networkConfig = properties.NetworkConfig{}
		computeFacade.CreateServerReturns(&servers.Server{ID: "123-456"}, nil)
		flavorResolver.ResolveFlavorForInstanceTypeReturns(flavors.Flavor{ID: "the_flavor_id", Name: "the_instance_type", RAM: 4096, Ephemeral: 10}, nil)
		computeFacade.GetOSKeyPairReturns(&keypairs.KeyPair{Name: "the_os_keypair_name"}, nil)
		defaultCloudConfig = properties.CreateVM{InstanceType: "the_instance_type", RootDisk: properties.Disk{Size: 1}}
		availabilityZoneProvider.GetAvailabilityZonesReturns([]string{"z1"})
		agentID = apiv1.NewAgentID("agent-id")
		env = apiv1.VMEnv{}
	})

	Context("GetServer", func() {

		It("returns error if server was failed to retrieved", func() {
			computeFacade.GetServerReturns(&servers.Server{ID: "123-456", Status: "ACTIVE"}, errors.New("boom"))
			_, err := computeService.GetServer("123-456")

			Expect(err.Error()).To(Equal("failed to retrieve server information: boom"))
		})

		It("returns an active server", func() {
			computeFacade.GetServerReturns(&servers.Server{ID: "123-456", Status: "ACTIVE"}, nil)
			server, err := computeService.GetServer("123-456")

			Expect(err).ToNot(HaveOccurred())
			Expect(server).ToNot(BeNil())
		})
	})

	Context("CreateServer", func() {

		BeforeEach(func() {
			computeFacade.GetServerReturns(&servers.Server{ID: "123-456", Status: "ACTIVE"}, nil)
		})

		It("resolves flavors by instance type", func() {
			_, err := computeService.CreateServer(
				apiv1.StemcellCID{},
				defaultCloudConfig,
				networkConfig,
				agentID,
				env,
				createCpiConfig(10),
			)

			Expect(err).ToNot(HaveOccurred())
			Expect(flavorResolver.ResolveFlavorForInstanceTypeArgsForCall(0)).To(Equal("the_instance_type"))
		})

		It("returns error if flavors resolution fails", func() {
			flavorResolver.ResolveFlavorForInstanceTypeReturns(flavors.Flavor{}, errors.New("boom"))

			_, err := computeService.CreateServer(
				apiv1.StemcellCID{},
				defaultCloudConfig,
				networkConfig,
				agentID,
				env,
				createCpiConfig(10),
			)

			Expect(err.Error()).To(ContainSubstring("failed to resolve flavor of instance type 'the_instance_type': boom"))
		})

		It("resolves the key pair via cloud config name", func() {
			computeFacade.GetOSKeyPairReturns(&keypairs.KeyPair{Name: "the_key_name"}, nil)

			_, _ = computeService.CreateServer( //nolint:errcheck
				apiv1.StemcellCID{},
				properties.CreateVM{
					InstanceType: "the_instance_type",
					KeyName:      "key_name_from_properties",
					RootDisk:     properties.Disk{Size: 0},
				},
				networkConfig,
				agentID,
				env,
				createCpiConfig(10),
			)

			_, keyPairName, _ := computeFacade.GetOSKeyPairArgsForCall(0)
			Expect(keyPairName).To(Equal("key_name_from_properties"))
		})

		It("resolves the key pair via openstack config name", func() {
			computeFacade.GetOSKeyPairReturns(&keypairs.KeyPair{Name: "the_key_name"}, nil)

			cpiConfig := config.CpiConfig{}
			openstackConfig := config.OpenstackConfig{StateTimeOut: 10, DefaultKeyName: "key_name_from_config"}
			cpiConfig.Cloud.Properties.Openstack = openstackConfig

			_, _ = computeService.CreateServer( //nolint:errcheck
				apiv1.StemcellCID{},
				defaultCloudConfig,
				networkConfig,
				agentID,
				env,
				cpiConfig,
			)

			_, keyPairName, _ := computeFacade.GetOSKeyPairArgsForCall(0)
			Expect(keyPairName).To(Equal("key_name_from_config"))
		})

		It("returns an error if key pair name IS NOT PROVIDED", func() {
			computeFacade.GetOSKeyPairReturns(nil, errors.New("boom"))

			cpiConfig := config.CpiConfig{}
			openstackConfig := config.OpenstackConfig{StateTimeOut: 10}
			cpiConfig.Cloud.Properties.Openstack = openstackConfig

			_, err := computeService.CreateServer(
				apiv1.StemcellCID{},
				defaultCloudConfig,
				networkConfig,
				agentID,
				env,
				cpiConfig,
			)

			Expect(err.Error()).To(Equal("failed to resolve keypair: key pair name undefined"))
		})

		It("returns an error id key pair name cannot be resolved", func() {
			computeFacade.GetOSKeyPairReturns(nil, errors.New("boom"))

			_, err := computeService.CreateServer(
				apiv1.StemcellCID{},
				defaultCloudConfig,
				networkConfig,
				agentID,
				env,
				createCpiConfig(10),
			)

			Expect(err.Error()).To(Equal("failed to resolve keypair: failed to retrieve 'the_key_name': boom"))
		})

		It("returns an error if the disksize is 0 in flavor and cloud properties", func() {
			volumeConfigurator.ConfigureVolumesReturns(nil, errors.New("boom"))

			_, err := computeService.CreateServer(
				apiv1.StemcellCID{},
				properties.CreateVM{InstanceType: "the_instance_type", RootDisk: properties.Disk{Size: 0}},
				networkConfig,
				agentID,
				env,
				createCpiConfig(10),
			)

			Expect(err.Error()).To(ContainSubstring("failed to configure volumes: boom"))
		})

		Context("with server create opts", func() {

			var bootFromVolume bool
			var networkConfig properties.NetworkConfig

			BeforeEach(func() {
				volumeConfigurator.ConfigureVolumesReturns([]bootfromvolume.BlockDevice{{
					UUID:                "the-stemcell-id",
					SourceType:          bootfromvolume.SourceImage,
					DestinationType:     bootfromvolume.DestinationVolume,
					VolumeSize:          999,
					BootIndex:           0,
					DeleteOnTermination: true,
				}}, nil)

				networkConfig = properties.NetworkConfig{
					ManualNetworks: []properties.Network{
						{Key: "bosh", Type: "manual", IP: "1.2.3.4", CloudProps: properties.NetworkCloudProps{NetID: "the_net_id"},
							Port: ports.Port{ID: "the_port_id"}},
					},
					VIPNetwork: &properties.Network{
						Key: "bosh-vip", Type: "vip", IP: "5.6.7.8", CloudProps: properties.NetworkCloudProps{NetID: "the_net_id"},
					},
					SecurityGroups: []string{"group_1", "group_2"},
				}

				bootFromVolume = true
			})

			It("creates opts for the server", func() {
				_, err := computeService.CreateServer(
					apiv1.NewStemcellCID("the_stemcell_id"),
					properties.CreateVM{
						InstanceType:     "the_instance_type",
						AvailabilityZone: "z1",
						RootDisk:         properties.Disk{Size: 1},
						BootFromVolume:   &bootFromVolume,
					},
					networkConfig,
					agentID,
					env,
					createCpiConfig(10),
				)
				Expect(err).ToNot(HaveOccurred())

				sClient, opts := computeFacade.CreateServerArgsForCall(0)
				Expect(sClient).To(BeAssignableToTypeOf(utilsServiceClient))

				createMap, err := opts.ToServerCreateMap()
				Expect(err).ToNot(HaveOccurred())
				server := createMap["server"].(map[string]interface{})
				serverNetworks := server["networks"].([]map[string]interface{})
				serverSecurityGroups := server["security_groups"].([]map[string]interface{})
				blockDevice := server["block_device_mapping_v2"].([]map[string]interface{})

				Expect(server["name"]).To(ContainSubstring("vm-"))
				Expect(server["imageRef"]).To(Equal("the_stemcell_id"))
				Expect(serverNetworks[0]["uuid"]).To(Equal("the_net_id"))
				Expect(serverNetworks[0]["port"]).To(Equal("the_port_id"))
				Expect(server["availability_zone"]).To(Equal("z1"))
				Expect(server["flavorRef"]).To(Equal("the_flavor_id"))
				Expect(server["key_name"]).To(Equal("the_os_keypair_name"))
				Expect(blockDevice[0]["uuid"]).To(Equal("the-stemcell-id"))
				Expect(blockDevice[0]["volume_size"]).To(Equal(999.0))
				Expect(serverSecurityGroups[0]["name"]).To(Equal("group_1"))
				Expect(serverSecurityGroups[1]["name"]).To(Equal("group_2"))
			})

			It("creates user data", func() {
				testEnv := map[string]interface{}{
					"key1": "value1",
					"key2": 1,
				}
				env = apiv1.NewVMEnv(testEnv)

				_, err := computeService.CreateServer(
					apiv1.NewStemcellCID("the_stemcell_id"),
					properties.CreateVM{
						InstanceType:     "the_instance_type",
						AvailabilityZone: "z1",
						RootDisk:         properties.Disk{Size: 1},
						BootFromVolume:   &bootFromVolume,
					},
					networkConfig,
					agentID,
					env,
					createCpiConfig(10),
				)
				Expect(err).ToNot(HaveOccurred())

				sClient, opts := computeFacade.CreateServerArgsForCall(0)
				Expect(sClient).To(BeAssignableToTypeOf(utilsServiceClient))

				createMap, err := opts.ToServerCreateMap()
				Expect(err).ToNot(HaveOccurred())
				server := createMap["server"].(map[string]interface{})

				userDataBytes, err := base64.StdEncoding.DecodeString(*server["user_data"].(*string))
				Expect(err).ToNot(HaveOccurred())

				userData := properties.UserData{}
				_ = json.Unmarshal(userDataBytes, &userData) //nolint:errcheck
				Expect(userData.Server.Name).To(Equal(server["name"]))
				Expect(userData.VM.Name).To(Equal(server["name"]))
				Expect(userData.Disks.System).To(Equal("/dev/sda"))

				Expect(userData.Networks["bosh"].IP).To(Equal("1.2.3.4"))
				Expect(*userData.Networks["bosh"].UseDHCP).To(BeTrue())
				Expect(userData.Networks["bosh-vip"].IP).To(Equal("5.6.7.8"))
				Expect(userData.Networks["bosh-vip"].UseDHCP).To(BeNil())
				Expect(userData.AgentID).To(Equal("agent-id"))

				environment, err := json.Marshal(userData.Env)
				Expect(err).ToNot(HaveOccurred())

				expectedEnv, err := json.Marshal(testEnv)
				Expect(err).ToNot(HaveOccurred())

				Expect(environment).To(Equal(expectedEnv))
			})
		})

		It("runs server creation in multiple AZs on creation failure", func() {
			availabilityZoneProvider.GetAvailabilityZonesReturns([]string{"z1", "z2"})

			computeFacade.CreateServerReturnsOnCall(0, nil, errors.New("boom"))
			computeFacade.CreateServerReturnsOnCall(1, &servers.Server{ID: "123-456"}, nil)

			_, _ = computeService.CreateServer( //nolint:errcheck
				apiv1.StemcellCID{},
				defaultCloudConfig,
				networkConfig,
				agentID,
				env,
				createCpiConfig(10),
			)

			_, opts := computeFacade.CreateServerArgsForCall(0)
			createMap, _ := opts.ToServerCreateMap() //nolint:errcheck
			server := createMap["server"].(map[string]interface{})
			Expect(server["availability_zone"]).To(Equal("z1"))

			_, opts = computeFacade.CreateServerArgsForCall(1)
			createMap, _ = opts.ToServerCreateMap() //nolint:errcheck
			server = createMap["server"].(map[string]interface{})
			Expect(server["availability_zone"]).To(Equal("z2"))

			Expect(computeFacade.CreateServerCallCount()).To(Equal(2))
		})

		It("runs server creation in multiple AZs if waiting in server fails", func() {
			availabilityZoneProvider.GetAvailabilityZonesReturns([]string{"z1", "z2"})

			computeFacade.GetServerReturns(&servers.Server{ID: "123-456", Status: "not-active"}, nil)

			compute.ComputeServicePollingInterval = 0

			_, _ = computeService.CreateServer( //nolint:errcheck
				apiv1.StemcellCID{},
				defaultCloudConfig,
				networkConfig,
				agentID,
				env,
				createCpiConfig(0),
			)

			_, opts := computeFacade.CreateServerArgsForCall(0)
			createMap, _ := opts.ToServerCreateMap() //nolint:errcheck
			server := createMap["server"].(map[string]interface{})
			Expect(server["availability_zone"]).To(Equal("z1"))

			_, opts = computeFacade.CreateServerArgsForCall(1)
			createMap, _ = opts.ToServerCreateMap() //nolint:errcheck
			server = createMap["server"].(map[string]interface{})
			Expect(server["availability_zone"]).To(Equal("z2"))

			Expect(computeFacade.CreateServerCallCount()).To(Equal(2))
		})

		It("returns an error if the server creation fails", func() {
			computeFacade.CreateServerReturns(nil, errors.New("boom"))

			server, err := computeService.CreateServer(
				apiv1.StemcellCID{},
				defaultCloudConfig,
				networkConfig,
				agentID,
				env,
				createCpiConfig(10),
			)

			Expect(err.Error()).To(Equal("failed to create server in availability zone 'z1': boom"))
			Expect(server).To(BeNil())
		})

		It("waits for the server to become ACTIVE", func() {
			computeFacade.GetServerReturnsOnCall(0, &servers.Server{ID: "123-456", Status: "not-active"}, nil)
			computeFacade.GetServerReturnsOnCall(1, &servers.Server{ID: "123-456", Status: "ACTIVE"}, nil)

			server, err := computeService.CreateServer(
				apiv1.StemcellCID{},
				defaultCloudConfig,
				networkConfig,
				agentID,
				env,
				createCpiConfig(10),
			)

			Expect(err).ToNot(HaveOccurred())
			Expect(server.ID).To(Equal("123-456"))
			Expect(computeFacade.GetServerCallCount()).To(Equal(2))
		})

		It("returns an error while waiting if getting server information fails", func() {
			computeFacade.GetServerReturns(nil, errors.New("boom"))

			server, err := computeService.CreateServer(
				apiv1.StemcellCID{},
				defaultCloudConfig,
				networkConfig,
				agentID,
				env,
				createCpiConfig(10),
			)

			Expect(err.Error()).To(Equal("failed while waiting on the server creation in availability zone 'z1': failed to retrieve server information: boom"))
			Expect(server).To(BeNil())
		})

		It("returns an error while waiting if the server creation finishes in state ERROR", func() {
			computeFacade.GetServerReturns(&servers.Server{ID: "123-456", Status: "ERROR"}, nil)

			server, err := computeService.CreateServer(
				apiv1.StemcellCID{},
				defaultCloudConfig,
				networkConfig,
				agentID,
				env,
				createCpiConfig(10),
			)

			Expect(err.Error()).To(Equal("failed while waiting on the server creation in availability zone 'z1': server became ERROR state while waiting to become ACTIVE"))
			Expect(server).To(Equal(&servers.Server{ID: "123-456", Status: "ERROR"}))
		})

		It("returns an error while waiting if the server creation finishes in state DELETED", func() {
			computeFacade.GetServerReturns(&servers.Server{ID: "123-456", Status: "DELETED"}, nil)

			server, err := computeService.CreateServer(
				apiv1.StemcellCID{},
				defaultCloudConfig,
				networkConfig,
				agentID,
				env,
				createCpiConfig(10),
			)

			Expect(err.Error()).To(Equal("failed while waiting on the server creation in availability zone 'z1': server became DELETED state while waiting to become ACTIVE"))
			Expect(server).To(Equal(&servers.Server{ID: "123-456", Status: "DELETED"}))
		})

		It("returns an error while waiting if the server creation times out", func() {
			computeFacade.GetServerReturns(&servers.Server{ID: "123-456", Status: "not-active"}, nil)

			server, err := computeService.CreateServer(
				apiv1.StemcellCID{},
				defaultCloudConfig,
				networkConfig,
				agentID,
				env,
				createCpiConfig(0),
			)

			Expect(err.Error()).To(Equal("failed while waiting on the server creation in availability zone 'z1': timeout while waiting for server to become active"))
			Expect(server).To(BeNil())
		})

		It("returns the id of the created server", func() {
			server, err := computeService.CreateServer(
				apiv1.StemcellCID{},
				defaultCloudConfig,
				networkConfig,
				agentID,
				env,
				createCpiConfig(10),
			)

			Expect(err).ToNot(HaveOccurred())
			Expect(server.ID).To(Equal("123-456"))
		})
	})

	Context("DeleteServer", func() {
		BeforeEach(func() {
			serverMetadata := make(map[string]string)
			serverMetadata["tag1"] = "tag1Value"
			serverMetadata["lbaas_pool_1"] = "poolID/memberID"

			computeFacade.GetServerReturnsOnCall(0, &servers.Server{ID: "123-456", Status: "ACTIVE"}, nil)
			computeFacade.GetServerReturnsOnCall(1, &servers.Server{ID: "123-456", Status: "DELETED"}, nil)
			computeFacade.GetServerMetadataReturns(serverMetadata, nil)
			loadbalancerService.DeletePoolMemberReturns(nil)
			computeFacade.DeleteServerReturns(nil)
		})

		It("deletes a server without raising errors", func() {
			err := computeService.DeleteServer(
				"123-456",
				createCpiConfig(10),
			)

			Expect(err).ToNot(HaveOccurred())
			Expect(computeFacade.GetServerCallCount()).To(Equal(2))
			Expect(computeFacade.DeleteServerCallCount()).To(Equal(1))
		})

		It("returns an error if getServer fails", func() {
			computeFacade.GetServerReturnsOnCall(0, nil, errors.New("boom"))

			err := computeService.DeleteServer(
				"123-456",
				createCpiConfig(10),
			)

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("failed to retrieve server information: boom"))
		})

		It("still succeeds if no server is found", func() {
			testError := gophercloud.ErrDefault404{
				ErrUnexpectedResponseCode: gophercloud.ErrUnexpectedResponseCode{Actual: 404},
			}
			computeFacade.GetServerReturnsOnCall(0, nil, testError)

			err := computeService.DeleteServer(
				"123-456",
				createCpiConfig(10),
			)

			Expect(err).ToNot(HaveOccurred())
		})

		It("returns an error if delete server fails", func() {
			computeFacade.DeleteServerReturns(errors.New("boom"))
			err := computeService.DeleteServer(
				"123-456",
				createCpiConfig(10),
			)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("failed to delete server: boom"))
		})

		It("waits for the server to become TERMINATED", func() {
			computeFacade.GetServerReturnsOnCall(1, &servers.Server{ID: "123-456", Status: "TERMINATED"}, nil)

			err := computeService.DeleteServer(
				"123-456",
				createCpiConfig(10),
			)

			Expect(err).ToNot(HaveOccurred())
			Expect(computeFacade.GetServerCallCount()).To(Equal(2))
		})

		It("still succeeds if server is not found while deletion", func() {
			testError := gophercloud.ErrDefault404{
				ErrUnexpectedResponseCode: gophercloud.ErrUnexpectedResponseCode{Actual: 404},
			}
			computeFacade.GetServerReturnsOnCall(1, nil, testError)

			err := computeService.DeleteServer(
				"123-456",
				createCpiConfig(10),
			)

			Expect(err).ToNot(HaveOccurred())
			Expect(computeFacade.DeleteServerCallCount()).To(Equal(1))
		})

		It("raises an error if it times out while waiting for the server to become DELETED", func() {
			computeFacade.GetServerReturns(&servers.Server{ID: "123-456", Status: "ACTIVE"}, nil)
			computeFacade.GetServerReturnsOnCall(1, &servers.Server{ID: "123-456", Status: "ACTIVE"}, nil)

			cpiConfig := createCpiConfig(0)

			err := computeService.DeleteServer(
				"123-456",
				cpiConfig,
			)

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("failed while waiting on the server deletion: timeout while waiting for server to become deleted"))
		})

		It("raises an error if server status has changed to ERROR instead of DELETED", func() {
			computeFacade.GetServerReturnsOnCall(1, &servers.Server{ID: "123-456", Status: "ERROR"}, nil)

			err := computeService.DeleteServer(
				"123-456",
				createCpiConfig(10),
			)

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("failed while waiting on the server deletion: server became ERROR state while waiting to become DELETED"))
		})

		It("raises an error if it server retrieval fails while waiting for the server to become DELETED", func() {
			computeFacade.GetServerReturnsOnCall(1, nil, errors.New("boom"))

			err := computeService.DeleteServer(
				"123-456",
				createCpiConfig(10),
			)

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("failed while waiting on the server deletion: failed to retrieve server information: boom"))
		})
	})

	Context("RebootServer", func() {
		BeforeEach(func() {
			computeFacade.GetServerReturns(&servers.Server{ID: "123-456", Status: "TERMINATED"}, nil)
			computeFacade.RebootServerReturns(nil)
		})

		It("gets the server information", func() {
			computeFacade.GetServerReturns(&servers.Server{ID: "123-456", Status: "ACTIVE"}, nil)

			err := computeService.RebootServer(
				"123-456",
				createCpiConfig(10),
			)

			Expect(err).ToNot(HaveOccurred())
			Expect(computeFacade.GetServerCallCount()).To(Equal(2))
		})

		It("waits for the server to become active", func() {
			computeFacade.GetServerReturnsOnCall(0, &servers.Server{ID: "123-456", Status: "ACTIVE"}, nil)
			computeFacade.GetServerReturnsOnCall(1, &servers.Server{ID: "123-456", Status: "TERMINATED"}, nil)
			computeFacade.GetServerReturnsOnCall(2, &servers.Server{ID: "123-456", Status: "ACTIVE"}, nil)

			err := computeService.RebootServer(
				"123-456",
				createCpiConfig(10),
			)

			Expect(err).ToNot(HaveOccurred())
			Expect(computeFacade.GetServerCallCount()).To(Equal(3))
		})

		It("fails retrieving the server", func() {
			computeFacade.GetServerReturns(nil, errors.New("boom"))

			err := computeService.RebootServer(
				"123-456",
				createCpiConfig(10),
			)

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("failed to retrieve server information: boom"))
		})

		It("failed to reboot the server", func() {
			computeFacade.GetServerReturns(&servers.Server{ID: "123-456", Status: "ACTIVE"}, nil)
			computeFacade.RebootServerReturns(errors.New("boom"))

			err := computeService.RebootServer(
				"123-456",
				createCpiConfig(10),
			)

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("failed to reboot server: boom"))
		})

		It("times out waiting for the server to become active", func() {
			computeFacade.GetServerReturnsOnCall(0, &servers.Server{ID: "123-456", Status: "ACTIVE"}, nil)

			err := computeService.RebootServer(
				"123-456",
				createCpiConfig(0),
			)

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("compute_service: timeout while waiting for server to become active"))
		})
	})

	Context("GetMetadata", func() {
		BeforeEach(func() {
			serverMetadata := make(map[string]string)
			serverMetadata["tag1"] = "tag1Value"
			serverMetadata["lbaas_pool_1"] = "poolID/memberID"

			computeFacade.GetServerMetadataReturns(serverMetadata, nil)

		})

		It("returns server metadata", func() {
			serverMetadata, err := computeService.GetMetadata(
				"123-456",
			)

			Expect(err).ToNot(HaveOccurred())
			Expect(serverMetadata).To(Equal(map[string]string{"tag1": "tag1Value", "lbaas_pool_1": "poolID/memberID"}))
		})

		It("returns empty metadata and no error if metadata not found", func() {
			testError := gophercloud.ErrDefault404{
				ErrUnexpectedResponseCode: gophercloud.ErrUnexpectedResponseCode{Actual: 404},
			}
			computeFacade.GetServerMetadataReturns(nil, testError)

			serverMetadata, err := computeService.GetMetadata(
				"123-456",
			)

			Expect(err).ToNot(HaveOccurred())
			Expect(serverMetadata).To(Equal(map[string]string{}))
		})

		It("returns an error if metadata retrieval fail", func() {
			computeFacade.GetServerMetadataReturns(nil, errors.New("boom"))

			_, err := computeService.GetMetadata(
				"123-456",
			)

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("failed to retrieve server metadata: boom"))
		})

	})

	Context("UpdateServer", func() {
		serverExp := servers.Server{ID: "123-456", Status: "ACTIVE"}

		It("updates a server without raising errors", func() {
			computeFacade.UpdateServerReturns(&serverExp, nil)
			serverResult, err := computeService.UpdateServer(
				"123-456",
				"test-server",
			)

			Expect(err).ToNot(HaveOccurred())
			Expect(*serverResult).To(Equal(serverExp))
		})

		It("returns an error if UpdateServer fails", func() {
			computeFacade.UpdateServerReturns(nil, errors.New("boom"))

			serverResult, err := computeService.UpdateServer(
				"123-456",
				"test-server",
			)

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("failed to update server: boom"))
			Expect(serverResult).To(BeNil())
		})

	})

	Context("UpdateServerMetadata", func() {
		var server servers.Server

		BeforeEach(func() {
			server = servers.Server{ID: "123-456"}
		})

		It("does not update metadata due to empty importing map", func() {
			server := servers.Server{ID: "123-456"}
			updateMetaDataMap := map[string]interface{}{}

			err := computeService.UpdateServerMetadata(server.ID, updateMetaDataMap)
			firstLoggerInfo, secondLoggerInfo, _ := logger.InfoArgsForCall(0)

			Expect(computeFacade.UpdateServerMetadataCallCount()).To(Equal(0))
			Expect(logger.InfoCallCount()).To(Equal(1))
			Expect(firstLoggerInfo).To(Equal("compute_service"))
			Expect(secondLoggerInfo).To(Equal("SKIPPING: No Metadata was found to be updated for server with id '123-456'"))
			Expect(err).ToNot(HaveOccurred())
		})

		It("does not update metadata due to importing map with only id", func() {
			updateMetaDataMap := map[string]interface{}{
				"id": "value1",
			}

			err := computeService.UpdateServerMetadata(server.ID, updateMetaDataMap)
			firstLoggerInfo, secondLoggerInfo, _ := logger.InfoArgsForCall(0)

			Expect(computeFacade.UpdateServerMetadataCallCount()).To(Equal(0))
			Expect(logger.InfoCallCount()).To(Equal(1))
			Expect(firstLoggerInfo).To(Equal("compute_service"))
			Expect(secondLoggerInfo).To(Equal("SKIPPING: No Metadata was found to be updated for server with id '123-456'"))
			Expect(err).ToNot(HaveOccurred())
		})

		It("returns an error if updating server metadata fails", func() {
			computeFacade.UpdateServerMetadataReturns(nil, errors.New("boom"))
			updateMetaDataMap := map[string]interface{}{
				"test": "value1",
			}

			err := computeService.UpdateServerMetadata(server.ID, updateMetaDataMap)

			Expect(err.Error()).To(Equal("failed to update server metadata: boom"))
		})

		It("returns no error if server metadata was updated successfully", func() {
			computeFacade.UpdateServerMetadataReturns(nil, nil)
			updateMetaDataMap := map[string]interface{}{
				"test": "value1",
			}

			err := computeService.UpdateServerMetadata(server.ID, updateMetaDataMap)

			Expect(err).ToNot(HaveOccurred())
			Expect(logger.InfoCallCount()).To(Equal(0))
		})
	})

	Context("DeleteServerMetadata", func() {
		var server servers.Server

		BeforeEach(func() {
			server = servers.Server{ID: "123-456"}
		})

		It("does not delete metadata due to empty updated importing map", func() {
			updateMetaDataMap := map[string]interface{}{}
			oldMetaDataMap := map[string]string{}

			err := computeService.DeleteServerMetaData(server.ID, oldMetaDataMap, updateMetaDataMap)
			firstLoggerInfo, secondLoggerInfo, _ := logger.InfoArgsForCall(0)

			Expect(computeFacade.UpdateServerMetadataCallCount()).To(Equal(0))
			Expect(logger.InfoCallCount()).To(Equal(1))
			Expect(firstLoggerInfo).To(Equal("compute_service"))
			Expect(secondLoggerInfo).To(Equal("SKIPPING: No metadata was provided to be deleted for server with id '123-456'"))
			Expect(err).ToNot(HaveOccurred())
		})

		It("does not delete metadata due to empty old importing map", func() {
			updateMetaDataMap := map[string]interface{}{
				"name":  "value1",
				"index": "value2",
				"test":  "value3",
			}
			oldMetaDataMap := map[string]string{
				"name":  "value1",
				"index": "value2",
			}

			err := computeService.DeleteServerMetaData(server.ID, oldMetaDataMap, updateMetaDataMap)
			firstLoggerInfo, secondLoggerInfo, _ := logger.InfoArgsForCall(0)

			Expect(computeFacade.UpdateServerMetadataCallCount()).To(Equal(0))
			Expect(logger.InfoCallCount()).To(Equal(1))
			Expect(firstLoggerInfo).To(Equal("compute_service"))
			Expect(secondLoggerInfo).To(Equal("SKIPPING: No metadata was provided to be deleted for server with id '123-456'"))
			Expect(err).ToNot(HaveOccurred())
		})

		It("returns error when deleting server metadata fails", func() {
			computeFacade.DeleteServerMetaDataReturns(errors.New("boom"))
			updateMetaDataMap := map[string]interface{}{
				"name":  "value1",
				"index": "value2",
				"test":  "value3",
			}
			oldMetaDataMap := map[string]string{
				"name":  "value1",
				"index": "value2",
				"test":  "value3",
			}

			err := computeService.DeleteServerMetaData(server.ID, oldMetaDataMap, updateMetaDataMap)

			Expect(err.Error()).To(Equal("failed to delete server metadata for key test: boom"))
			Expect(computeFacade.DeleteServerMetaDataCallCount()).To(Equal(1))
		})

		It("does not delete metadata due to empty importing map", func() {
			updateMetaDataMap := map[string]interface{}{
				"name":  "value1",
				"index": "value2",
				"test":  "value3",
			}
			oldMetaDataMap := map[string]string{
				"name":  "value1",
				"index": "value2",
				"test":  "value3",
			}

			err := computeService.DeleteServerMetaData(server.ID, oldMetaDataMap, updateMetaDataMap)
			_, actServerID, actMapKey := computeFacade.DeleteServerMetaDataArgsForCall(0)

			Expect(err).ToNot(HaveOccurred())
			Expect(computeFacade.DeleteServerMetaDataCallCount()).To(Equal(1))
			Expect(actServerID).To(Equal(server.ID))
			Expect(actMapKey).To(Equal("test"))
		})

	})

	Context("GetMatchingFlavor", func() {
		var vmResources apiv1.VMResources

		BeforeEach(func() {
			vmResources = apiv1.VMResources{CPU: 2, RAM: 4096, EphemeralDiskSize: 10}
		})

		Context("GetMatchingFlavor", func() {
			It("returns the flavor", func() {
				possibleFlavors := []flavors.Flavor{{ID: "the_flavor_id", Name: "the_instance_type", VCPUs: 2, RAM: 4096, Ephemeral: 10}}
				matchedFlavor := flavors.Flavor{ID: "the_flavor_id", Name: "the_instance_type", VCPUs: 2, RAM: 4096, Ephemeral: 10}
				flavorResolver.ResolveFlavorForRequirementsReturns(possibleFlavors, nil)
				flavorResolver.GetClosestMatchedFlavorReturns(matchedFlavor)

				returnedFlavor, err := computeService.GetMatchingFlavor(vmResources, false)
				inputFlavor := flavorResolver.GetClosestMatchedFlavorArgsForCall(0)
				Expect(err).ToNot(HaveOccurred())
				Expect(inputFlavor).To(Equal(possibleFlavors))
				Expect(returnedFlavor).To(Equal(matchedFlavor))
			})
		})

		It("returns an error if no flavor is found", func() {
			flavorResolver.ResolveFlavorForRequirementsReturns([]flavors.Flavor{}, nil)

			_, err := computeService.GetMatchingFlavor(vmResources, false)

			Expect(err.Error()).To(ContainSubstring("Unable to meet requested VM requirements:"))
		})

		It("returns an error if flavorResolver.ResolveFlavorForRequirements returns an error", func() {
			flavorResolver.ResolveFlavorForRequirementsReturns([]flavors.Flavor{}, errors.New("boom"))

			_, err := computeService.GetMatchingFlavor(vmResources, false)

			Expect(err.Error()).To(ContainSubstring("failed to get flavors:"))
		})
	})
})

func createCpiConfig(stateTimeOut int) config.CpiConfig {
	cpiConfig := config.CpiConfig{}
	cpiConfig.Cloud.Properties.Openstack =
		config.OpenstackConfig{StateTimeOut: stateTimeOut, DefaultKeyName: "the_key_name", UseDHCP: true}
	return cpiConfig
}
