package methods

import (
	"fmt"
	"strconv"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/compute"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/image"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/loadbalancer"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/network"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/servers"
	"github.com/gophercloud/gophercloud/openstack/loadbalancer/v2/pools"
	"github.com/gophercloud/gophercloud/openstack/networking/v2/ports"
)

type CreateVMMethod struct {
	imageServiceBuilder        image.ImageServiceBuilder
	networkServiceBuilder      network.NetworkServiceBuilder
	computeServiceBuilder      compute.ComputeServiceBuilder
	loadbalancerServiceBuilder loadbalancer.LoadbalancerServiceBuilder
	cpiConfig                  config.CpiConfig
	logger                     utils.Logger
}

func NewCreateVMMethod(
	imageServiceBuilder image.ImageServiceBuilder,
	networkServiceBuilder network.NetworkServiceBuilder,
	computeServiceBuilder compute.ComputeServiceBuilder,
	loadbalancerServiceBuilder loadbalancer.LoadbalancerServiceBuilder,
	cpiConfig config.CpiConfig,
	logger utils.Logger,
) CreateVMMethod {
	return CreateVMMethod{
		imageServiceBuilder:        imageServiceBuilder,
		networkServiceBuilder:      networkServiceBuilder,
		computeServiceBuilder:      computeServiceBuilder,
		loadbalancerServiceBuilder: loadbalancerServiceBuilder,
		cpiConfig:                  cpiConfig,
		logger:                     logger,
	}
}

func (m CreateVMMethod) CreateVM(
	agentID apiv1.AgentID, stemcellCID apiv1.StemcellCID, cloudProps apiv1.VMCloudProps,
	networks apiv1.Networks, diskCIDs []apiv1.DiskCID, env apiv1.VMEnv) (apiv1.VMCID, error) {

	return apiv1.VMCID{}, nil
}

func (m CreateVMMethod) CreateVMV2(
	agentID apiv1.AgentID, stemcellCID apiv1.StemcellCID, props apiv1.VMCloudProps,
	networks apiv1.Networks, diskCIDs []apiv1.DiskCID, env apiv1.VMEnv) (apiv1.VMCID, apiv1.Networks, error) {

	cloudProps := properties.CreateVM{}
	err := props.As(&cloudProps)
	if err != nil {
		return apiv1.VMCID{}, apiv1.Networks{}, fmt.Errorf("failed to parse vm cloud properties: %w", err)
	}

	createdPortsIds := make([]ports.Port, 0)

	err = cloudProps.Validate(m.cpiConfig.Cloud.Properties.Openstack)
	if err != nil {
		return apiv1.VMCID{}, apiv1.Networks{}, fmt.Errorf("failed to validate cloud properties: %w", err)
	}

	computeService, err := m.computeServiceBuilder.Build()
	if err != nil {
		return apiv1.VMCID{}, apiv1.Networks{}, fmt.Errorf("failed to create compute service: %w", err)
	}

	networkService, err := m.networkServiceBuilder.Build()
	if err != nil {
		return apiv1.VMCID{}, apiv1.Networks{}, fmt.Errorf("failed to create networking service: %w", err)
	}

	imageService, err := m.imageServiceBuilder.Build()
	if err != nil {
		return apiv1.VMCID{}, apiv1.Networks{}, fmt.Errorf("failed to create image service: %w", err)
	}

	loadbalancerService, err := m.loadbalancerServiceBuilder.Build()
	if err != nil {
		return apiv1.VMCID{}, apiv1.Networks{}, fmt.Errorf("failed to create loadbalancer service: %w", err)
	}

	_, err = imageService.GetImage(stemcellCID.AsString())
	if err != nil {
		return apiv1.VMCID{}, apiv1.Networks{}, fmt.Errorf("failed to resolve stemcell: %w", err)
	}

	networkConfig, err := networkService.GetNetworkConfiguration(networks, m.cpiConfig.Cloud.Properties.Openstack, cloudProps)
	if err != nil {
		return apiv1.VMCID{}, apiv1.Networks{}, fmt.Errorf("failed to create network config: %w", err)
	}

	manualNetworks := networkConfig.ManualNetworks
	for i := 0; i < len(manualNetworks); i++ {
		manualNetwork := &manualNetworks[i]
		port, err := networkService.CreatePort(*manualNetwork, networkConfig.SecurityGroups, cloudProps)
		if err != nil {
			return apiv1.VMCID{}, apiv1.Networks{}, fmt.Errorf("failed to create port: %w", err)
		}
		manualNetwork.ConfigurePort(port)
		createdPortsIds = append(createdPortsIds, port)
	}

	server, err := computeService.CreateServer(stemcellCID, cloudProps, networkConfig, agentID, env, m.cpiConfig)
	if err != nil {
		return m.cleanupServerResources(
			server,
			createdPortsIds,
			[]pools.Member{},
			computeService,
			loadbalancerService,
			networkService,
			fmt.Errorf("failed to create server: %w", err),
		)
	}

	err = networkService.ConfigureVIPNetwork(server.ID, networkConfig)
	if err != nil {
		return m.cleanupServerResources(
			server,
			createdPortsIds,
			[]pools.Member{},
			computeService,
			loadbalancerService,
			networkService,
			fmt.Errorf("failed to configure vip network for server '%s' with error: %w", server.ID, err),
		)
	}

	poolMembers, err := m.configureLoadbalancerPools(loadbalancerService, networkService, cloudProps, networkConfig)
	if err != nil {
		return m.cleanupServerResources(
			server,
			createdPortsIds,
			poolMembers,
			computeService,
			loadbalancerService,
			networkService,
			fmt.Errorf("failed to configure loadbalancer pools: %w", err),
		)
	}

	err = computeService.UpdateServerMetadata(server.ID, m.getServerMetadata(poolMembers))
	if err != nil {
		return m.cleanupServerResources(
			server,
			createdPortsIds,
			poolMembers,
			computeService,
			loadbalancerService,
			networkService,
			fmt.Errorf("failed to update metadata for server '%s' with error: %w", server.ID, err),
		)
	}

	return apiv1.NewVMCID(server.ID), networks, nil
}

func (m CreateVMMethod) configureLoadbalancerPools(
	loadbalancerService loadbalancer.LoadbalancerService,
	networkService network.NetworkService,
	cloudProps properties.CreateVM,
	networkConfig properties.NetworkConfig,
) ([]pools.Member, error) {
	var poolMemberships []pools.Member

	for _, poolProperties := range cloudProps.LoadbalancerPools {
		pool, err := loadbalancerService.GetPool(poolProperties.Name)
		if err != nil {
			return poolMemberships, fmt.Errorf("failed to get pool ID of pool '%s': %w", poolProperties.Name, err)
		}
		m.logger.Info("create_vm_method", fmt.Sprintf("Resolved pool id '%s' for pool '%s'", pool.ID, poolProperties.Name))

		ip := networkConfig.DefaultNetwork.IP

		defaultNetworkID := networkConfig.DefaultNetwork.CloudProps.NetID

		subnetID, err := networkService.GetSubnetID(defaultNetworkID, ip)
		if err != nil {
			return poolMemberships, fmt.Errorf("failed to get subnet: %w", err)
		}

		poolMember, err := loadbalancerService.CreatePoolMember(pool, ip, poolProperties, subnetID, m.cpiConfig.Cloud.Properties.Openstack.StateTimeOut)
		if err != nil {
			return poolMemberships, fmt.Errorf("failed to create pool membership of IP '%s' in pool '%s': %w", ip, pool.ID, err)
		}

		poolMember.PoolID = pool.ID
		poolMemberships = append(poolMemberships, *poolMember)

		m.logger.Info("create_vm_method", fmt.Sprintf("created pool member '%+v' in pool '%s'", *poolMember, pool.ID))
	}

	return poolMemberships, nil
}

func (m CreateVMMethod) getServerMetadata(members []pools.Member) properties.ServerMetadata {
	tags := properties.ServerMetadata{}

	var index = 1
	for _, member := range members {
		itoa := strconv.Itoa(index)
		tags["lbaas_pool_"+itoa] = member.PoolID + "/" + member.ID
		index++
	}

	return tags
}

func (m CreateVMMethod) cleanupServerResources(
	server *servers.Server, ports []ports.Port, poolMembers []pools.Member, computeService compute.ComputeService,
	loadbalancerService loadbalancer.LoadbalancerService, networkService network.NetworkService, errorMsg error) (
	apiv1.VMCID, apiv1.Networks, error) {

	for _, poolMember := range poolMembers {
		err := loadbalancerService.DeletePoolMember(poolMember.PoolID, poolMember.ID, m.cpiConfig.Cloud.Properties.Openstack.StateTimeOut)
		if err != nil {
			m.logger.Warn("create_vm_method",
				fmt.Sprintf("failed while cleaning up pool member: '%s' in pool '%s' with error: %s",
					poolMember.ID, poolMember.PoolID, err.Error()))
			continue
		}
	}

	if server != nil {
		err := computeService.DeleteServer(server.ID, m.cpiConfig)
		if err != nil {
			m.logger.Warn("create_vm_method",
				fmt.Sprintf("failed while cleaning up server '%s' with error: %s", server.ID, err.Error()))
		}
	}

	err := networkService.DeletePorts(ports)
	if err != nil {
		m.logger.Warn("create_vm_method",
			fmt.Sprintf("failed while cleaning up ports: '%+v' with error: %s", ports, err.Error()))
	}

	return apiv1.VMCID{}, apiv1.Networks{}, errorMsg
}
