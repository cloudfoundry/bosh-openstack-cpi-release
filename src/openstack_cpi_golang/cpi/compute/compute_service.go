package compute

import (
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/google/uuid"
	"github.com/gophercloud/gophercloud"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/extensions/bootfromvolume"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/extensions/keypairs"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/extensions/volumeattach"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/flavors"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/servers"
)

var ComputeServicePollingInterval = 10 * time.Second

//counterfeiter:generate . ComputeService
type ComputeService interface {
	GetServer(
		serverID string,
	) (*servers.Server, error)

	CreateServer(
		stemcellCID apiv1.StemcellCID,
		cloudProps properties.CreateVM,
		networkConfig properties.NetworkConfig,
		agentID apiv1.AgentID,
		env apiv1.VMEnv,
		cpiConfig config.CpiConfig,
	) (*servers.Server, error)

	DeleteServer(
		serverID string,
		cpiConfig config.CpiConfig,
	) error

	RebootServer(
		serverID string,
		cpiConfig config.CpiConfig,
	) error

	GetMetadata(
		serverID string,
	) (map[string]string, error)

	UpdateServer(
		serverID string,
		serverName string,
	) (*servers.Server, error)

	UpdateServerMetadata(
		serverID string,
		serverMetadata properties.ServerMetadata,
	) error

	DeleteServerMetaData(
		serverID string,
		oldMetaDataMap map[string]string,
		updateMetaDataMap properties.ServerMetadata,
	) error

	GetMatchingFlavor(
		vmResources apiv1.VMResources,
		bootFromVolume bool,
	) (flavors.Flavor, error)

	GetServerAZ(
		vmcid string,
	) (string, error)

	AttachVolume(
		serverID string,
		volumeID string,
		device string,
	) (*volumeattach.VolumeAttachment, error)

	DetachVolume(
		serverID string,
		volumeID string,
	) error

	ListVolumeAttachments(
		serverID string,
	) ([]volumeattach.VolumeAttachment, error)

	GetFlavorById(
		flavorId string,
	) (flavors.Flavor, error)
}

type computeService struct {
	serviceClients           utils.ServiceClients
	computeFacade            ComputeFacade
	flavorResolver           FlavorResolver
	volumeConfigurator       VolumeConfigurator
	availabilityZoneProvider AvailabilityZoneProvider
	logger                   utils.Logger
}

func NewComputeService(
	serviceClients utils.ServiceClients,
	computeFacade ComputeFacade,
	flavorResolver FlavorResolver,
	volumeConfigurator VolumeConfigurator,
	availabilityZoneProvider AvailabilityZoneProvider,
	logger utils.Logger,
) computeService {
	return computeService{
		serviceClients:           serviceClients,
		computeFacade:            computeFacade,
		flavorResolver:           flavorResolver,
		volumeConfigurator:       volumeConfigurator,
		availabilityZoneProvider: availabilityZoneProvider,
		logger:                   logger,
	}
}

func (c computeService) GetServer(
	serverID string,
) (*servers.Server, error) {
	server, err := c.computeFacade.GetServer(c.serviceClients.RetryableServiceClient, serverID)
	if err != nil {
		return nil, fmt.Errorf("failed to retrieve server information: %w", err)
	}
	return server, nil
}

func (c computeService) GetServerAZ(
	serverID string,
) (string, error) {
	serverWithAz, err := c.computeFacade.GetServerWithAZ(c.serviceClients.RetryableServiceClient, serverID)

	if err != nil {
		return "", fmt.Errorf("failed to retrieve server information: %w", err)
	}
	return serverWithAz.AvailabilityZone, nil
}

func (c computeService) CreateServer(
	stemcellCID apiv1.StemcellCID,
	cloudProps properties.CreateVM,
	networkConfig properties.NetworkConfig,
	agentID apiv1.AgentID,
	env apiv1.VMEnv,
	cpiConfig config.CpiConfig,
) (*servers.Server, error) {
	openstackConfig := cpiConfig.Cloud.Properties.Openstack

	flavor, err := c.flavorResolver.ResolveFlavorForInstanceType(cloudProps.InstanceType)
	if err != nil {
		return nil, fmt.Errorf("failed to resolve flavor of instance type '%s': %w", cloudProps.InstanceType, err)
	}

	keyname, err := c.getKeyPairName(cloudProps, openstackConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to resolve keypair: %w", err)
	}

	blockDevices, err := c.volumeConfigurator.ConfigureVolumes(stemcellCID.AsString(), openstackConfig, cloudProps, flavor)
	if err != nil {
		return nil, fmt.Errorf("failed to configure volumes: %w", err)
	}

	vmName := c.getVMName()

	userData, err := c.createServerUserData(networkConfig, cpiConfig, vmName, flavor, agentID, env)
	if err != nil {
		return nil, fmt.Errorf("failed to create user data: %w", err)
	}

	userDataJson, err := json.Marshal(userData)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal user data: %w", err)
	}

	var server *servers.Server
	availabilityZones := c.availabilityZoneProvider.GetAvailabilityZones(cloudProps)

	for _, availabilityZone := range availabilityZones {
		createOpts := c.getServerCreateOpts(vmName, availabilityZone, stemcellCID, networkConfig, flavor, keyname, blockDevices, userDataJson)

		server, err = c.computeFacade.CreateServer(c.serviceClients.ServiceClient, createOpts)
		if err != nil {
			if availabilityZone == availabilityZones[len(availabilityZones)-1] {
				return nil, fmt.Errorf("failed to create server in availability zone '%s': %w", availabilityZone, err)
			}
			c.logger.Warn("failed to create server in availability zone '%s': %v, "+
				"retrying in a different availability zone", availabilityZone, err)

			continue
		}

		server, err = c.waitForServerToBecomeActive(server.ID, time.Duration(openstackConfig.StateTimeOut)*time.Second)
		if err != nil {
			if availabilityZone == availabilityZones[len(availabilityZones)-1] {
				return server, fmt.Errorf("failed while waiting on the server creation in availability zone '%s': %w", availabilityZone, err)
			}
			c.logger.Warn("failed while waiting on the server creation in availability zone '%s': %v, "+
				"retrying in a different availability zone", availabilityZone, err)

			continue
		}

		break
	}

	return server, nil
}

func (c computeService) DeleteServer(
	serverID string,
	cpiConfig config.CpiConfig,
) error {
	var errDefault404 gophercloud.ErrDefault404

	_, err := c.GetServer(serverID)
	if err != nil {
		if errors.As(err, &errDefault404) {
			c.logger.Info("compute_service", fmt.Sprintf("SKIPPING: Server deletion with id '%s' is not found", serverID))
			return nil
		}
		return err
	}

	err = c.computeFacade.DeleteServer(c.serviceClients.RetryableServiceClient, serverID)
	if err != nil && !errors.As(err, &errDefault404) {
		return fmt.Errorf("failed to delete server: %w", err)
	}

	timeout := time.Duration(cpiConfig.Cloud.Properties.Openstack.StateTimeOut) * time.Second
	err = c.waitForServerToBecomeDeleted(serverID, timeout)
	if err != nil {
		return fmt.Errorf("failed while waiting on the server deletion: %w", err)
	}

	c.logger.Info("compute_service", fmt.Sprintf("Deleted server with id '%s'", serverID))

	// deleting registry settings - Seems that it is not needed for V2
	// https://bosh.io/docs/cpi-api-v2/#reference-table-based-on-each-component-version

	return nil
}

func (c computeService) RebootServer(
	serverID string,
	cpiConfig config.CpiConfig,
) error {
	_, err := c.GetServer(serverID)
	if err != nil {
		return err
	}

	rebootOpts := servers.RebootOpts{
		Type: servers.SoftReboot,
	}

	err = c.computeFacade.RebootServer(c.serviceClients.ServiceClient, serverID, rebootOpts)
	if err != nil {
		return fmt.Errorf("failed to reboot server: %w", err)
	}

	_, err = c.waitForServerToBecomeActive(
		serverID,
		time.Duration(cpiConfig.Cloud.Properties.Openstack.StateTimeOut)*time.Second,
	)
	if err != nil {
		return fmt.Errorf("compute_service: %w", err)
	}

	return nil
}

func (c computeService) GetMetadata(serverID string) (map[string]string, error) {
	var errDefault404 gophercloud.ErrDefault404

	serverMetadata, err := c.computeFacade.GetServerMetadata(c.serviceClients.RetryableServiceClient, serverID)
	if err != nil {
		if errors.As(err, &errDefault404) {
			c.logger.Info("compute_service", fmt.Sprintf("SKIPPING: Metadata retrieval for server with id '%s' is not found", serverID))
			serverMetadata = map[string]string{}
		} else {
			return nil, fmt.Errorf("failed to retrieve server metadata: %w", err)
		}
	}
	return serverMetadata, nil
}

func (c computeService) UpdateServer(serverID string, serverName string) (*servers.Server, error) {

	updateOptsBuilder := servers.UpdateOpts{
		Name: serverName,
	}

	server, err := c.computeFacade.UpdateServer(c.serviceClients.ServiceClient, serverID, updateOptsBuilder)
	if err != nil {
		return nil, fmt.Errorf("failed to update server: %w", err)
	}
	return server, nil

}

func (c computeService) UpdateServerMetadata(serverID string, serverMetadata properties.ServerMetadata) error {
	var blacklistedMetadataKeys = []string{
		"id",
	}

	updateMetadataOpts := servers.MetadataOpts{}
	for k, v := range serverMetadata {
		updateMetadataOpts[k] = v.(string)
	}

	for _, key := range blacklistedMetadataKeys {
		delete(updateMetadataOpts, key)
	}

	if len(updateMetadataOpts) == 0 {
		c.logger.Info("compute_service", fmt.Sprintf("SKIPPING: No Metadata was found to be updated for server with id '%s'", serverID))
		return nil
	}

	_, err := c.computeFacade.UpdateServerMetadata(c.serviceClients.ServiceClient, serverID, updateMetadataOpts)
	if err != nil {
		return fmt.Errorf("failed to update server metadata: %w", err)
	}

	return nil
}

func (c computeService) DeleteServerMetaData(
	serverID string,
	oldMetaDataMap map[string]string,
	updateMetaDataMap properties.ServerMetadata,
) error {
	if length := len(updateMetaDataMap); length == 0 {
		c.logger.Info("compute_service", fmt.Sprintf("SKIPPING: No metadata was provided to be deleted for server with id '%s'", serverID))
		return nil
	}

	var oldMetaDataMapToBeDeleted = map[string]string{}

	//it is not required to delete blacklisted metadata (key); they get updated without prior deletion
	//(keeping the sequence in the dashboard)
	var blacklistedMetadataKeysOld = []string{
		"director",
		"deployment",
		"instance_group",
		"job",
		"id",
		"name",
		"index",
		"created_at",
		"compiling",
	}

	for _, key := range blacklistedMetadataKeysOld {
		delete(oldMetaDataMap, key)
	}

	if length := len(oldMetaDataMap); length == 0 {
		c.logger.Info("compute_service", fmt.Sprintf("SKIPPING: No metadata was provided to be deleted for server with id '%s'", serverID))
		return nil
	}

	for key, value := range oldMetaDataMap {
		if _, exists := updateMetaDataMap[key]; exists {
			oldMetaDataMapToBeDeleted[key] = value
		}
	}

	for id := range oldMetaDataMapToBeDeleted {
		err := c.computeFacade.DeleteServerMetaData(c.serviceClients.ServiceClient, serverID, id)
		if err != nil {
			return fmt.Errorf("failed to delete server metadata for key %s: %w", id, err)
		}
	}

	return nil
}

func (c computeService) GetMatchingFlavor(vmResources apiv1.VMResources, bootFromVolume bool) (flavors.Flavor, error) {
	possibleFlavors, err := c.flavorResolver.ResolveFlavorForRequirements(vmResources, bootFromVolume)
	if err != nil {
		return flavors.Flavor{}, fmt.Errorf("failed to get flavors: %w", err)
	}

	if len(possibleFlavors) == 0 {
		return flavors.Flavor{}, fmt.Errorf("Unable to meet requested VM requirements: %d CPU, %d MB RAM, %g GB Disk.\n", //nolint:staticcheck
			vmResources.CPU,
			vmResources.RAM,
			float64(vmResources.EphemeralDiskSize)/1024,
		)
	}

	matchedFlavor := c.flavorResolver.GetClosestMatchedFlavor(possibleFlavors)

	return matchedFlavor, nil

}

func (c computeService) createServerUserData(
	networkConfig properties.NetworkConfig,
	cpiConfig config.CpiConfig,
	vmName string,
	flavor flavors.Flavor,
	agentID apiv1.AgentID,
	env apiv1.VMEnv,
) (properties.UserData, error) {
	userDataNetwork := map[string]properties.UserdataNetwork{}
	for _, network := range networkConfig.AllNetworks() {

		userdataNetwork := properties.UserdataNetwork{
			Default:    network.Default,
			DNS:        network.DNS,
			IP:         network.IP,
			Gateway:    network.Gateway,
			Netmask:    network.Netmask,
			Type:       network.Type,
			CloudProps: network.CloudProps,
			Mac:        network.Mac,
		}

		if network.Type != "vip" {
			userdataNetwork.UseDHCP = &cpiConfig.Cloud.Properties.Openstack.UseDHCP
		}

		userDataNetwork[network.Key] = userdataNetwork
	}

	environment, err := env.MarshalJSON()
	if err != nil {
		return properties.UserData{}, fmt.Errorf("failed to marshal environment")
	}

	return properties.NewUserDataBuilder().
		WithServer(properties.Server{Name: vmName}).
		WithNetworks(userDataNetwork).
		WithVM(properties.VM{Name: vmName}).
		WithNetworks(userDataNetwork).
		WithEphemeralDiskSize(flavor.Ephemeral).
		WithAgentID(agentID).
		WithEnvironment(environment).
		WithConfig(cpiConfig).
		Build(), nil
}

func (c computeService) getServerCreateOpts(
	vmName string,
	availabilityZone string,
	stemcellCID apiv1.StemcellCID,
	networkConfig properties.NetworkConfig,
	flavor flavors.Flavor, keyname string,
	blockDevices []bootfromvolume.BlockDevice,
	userDataJson []byte,
) servers.CreateOptsBuilder {

	var createOpts servers.CreateOptsBuilder
	createOpts = servers.CreateOpts{
		Name:             vmName,
		ImageRef:         stemcellCID.AsString(),
		Networks:         c.getServerNetworks(networkConfig),
		AvailabilityZone: availabilityZone,
		FlavorRef:        flavor.ID,
		UserData:         userDataJson,

		//Security groups are set for dynamic networks here.
		//For manual networks, security groups are set on the port.
		SecurityGroups: networkConfig.SecurityGroups,
	}

	createOpts = keypairs.CreateOptsExt{
		CreateOptsBuilder: createOpts,
		KeyName:           keyname,
	}

	if len(blockDevices) > 0 {
		createOpts = bootfromvolume.CreateOptsExt{
			CreateOptsBuilder: createOpts,
			BlockDevice:       blockDevices,
		}
	}
	return createOpts
}

func (c computeService) getKeyPairName(cloudProps properties.CreateVM, openstackConfig config.OpenstackConfig) (string, error) {
	var keyPairName string

	if cloudProps.KeyName != "" {
		keyPairName = cloudProps.KeyName
	} else {
		keyPairName = openstackConfig.DefaultKeyName
	}

	if keyPairName == "" {
		return "", fmt.Errorf("key pair name undefined")
	}

	keypair, err := c.computeFacade.GetOSKeyPair(c.serviceClients.RetryableServiceClient, keyPairName, keypairs.GetOpts{})
	if err != nil {
		return "", fmt.Errorf("failed to retrieve '%s': %w", keyPairName, err)
	}

	return keypair.Name, nil
}

func (c computeService) getServerNetworks(networkConfig properties.NetworkConfig) []servers.Network {
	var serverNetworks []servers.Network
	for _, network := range networkConfig.ManualNetworks {
		serverNetworks = append(serverNetworks, servers.Network{UUID: network.CloudProps.NetID, Port: network.Port.ID})
	}

	dynamicNetwork := networkConfig.DynamicNetwork
	if dynamicNetwork != nil {
		serverNetworks = append(serverNetworks, servers.Network{UUID: dynamicNetwork.CloudProps.NetID})
	}
	return serverNetworks
}

func (c computeService) getVMName() string {
	return "vm-" + uuid.New().String()
}

func (c computeService) waitForServerToBecomeActive(serverID string, timeout time.Duration) (*servers.Server, error) {
	timeoutTimer := time.NewTimer(timeout)

	for {
		select {
		case <-timeoutTimer.C:
			return nil, fmt.Errorf("timeout while waiting for server to become active")
		default:
			server, err := c.GetServer(serverID)
			if err != nil {
				return nil, err
			}

			switch server.Status {
			case "ACTIVE":
				return server, nil
			case "ERROR":
				return nil, fmt.Errorf("server became ERROR state while waiting to become ACTIVE")
			case "DELETED":
				return nil, fmt.Errorf("server became DELETED state while waiting to become ACTIVE")
			}

			time.Sleep(ComputeServicePollingInterval)
		}
	}
}

func (c computeService) waitForServerToBecomeDeleted(serverID string, timeout time.Duration) error {
	var errDefault404 gophercloud.ErrDefault404
	timeoutTimer := time.NewTimer(timeout)

	for {
		select {
		case <-timeoutTimer.C:
			return fmt.Errorf("timeout while waiting for server to become deleted")
		default:
			server, err := c.GetServer(serverID)
			if err != nil {
				if errors.As(err, &errDefault404) {
					return nil
				}
				return err
			}

			switch server.Status {
			case "DELETED":
				return nil
			case "TERMINATED":
				return nil
			case "ERROR":
				return fmt.Errorf("server became ERROR state while waiting to become DELETED")
			}

			time.Sleep(ComputeServicePollingInterval)
		}
	}
}

func (c computeService) AttachVolume(serverID string, volumeID string, device string) (*volumeattach.VolumeAttachment, error) {
	// see: https://github.com/gophercloud/gophercloud/blob/master/openstack/compute/v2/volumeattach/doc.go
	opts := volumeattach.CreateOpts{
		Device:   device,
		VolumeID: volumeID,
	}
	return c.computeFacade.AttachVolume(c.serviceClients.ServiceClient, serverID, opts)
}

func (c computeService) DetachVolume(serverID string, volumeID string) error {
	return c.computeFacade.DetachVolume(c.serviceClients.ServiceClient, serverID, volumeID)
}

func (c computeService) ListVolumeAttachments(serverID string) ([]volumeattach.VolumeAttachment, error) {
	return c.computeFacade.ListVolumeAttachments(c.serviceClients.ServiceClient, serverID)
}

func (c computeService) GetFlavorById(flavorId string) (flavors.Flavor, error) {
	return c.flavorResolver.GetFlavorById(flavorId)
}
