package network

import (
	"fmt"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/gophercloud/gophercloud/openstack/networking/v2/extensions/security/groups"
)

//counterfeiter:generate . SecurityGroupsResolver
type SecurityGroupsResolver interface {
	Resolve(securityGroupIDsAndNames []string) ([]string, error)
}

type securityGroupsResolver struct {
	serviceClients   utils.ServiceClients
	networkingFacade NetworkingFacade
	logger           utils.Logger
}

func NewSecurityGroupsResolver(
	serviceClients utils.ServiceClients,
	networkingFacade NetworkingFacade,
	logger utils.Logger,
) securityGroupsResolver {
	return securityGroupsResolver{
		serviceClients:   serviceClients,
		networkingFacade: networkingFacade,
		logger:           logger,
	}
}

func (s securityGroupsResolver) Resolve(securityGroupIDsAndNames []string) ([]string, error) {
	var securityGroupIds []string
	var resolvedSecurityGroup *groups.SecGroup
	var err error

	for _, securityGroup := range securityGroupIDsAndNames {
		resolvedSecurityGroup, err = s.resolveSecurityGroupById(securityGroup)
		if err != nil {
			s.logger.Warn("security-group-resolver", fmt.Sprintf("failed to get security group '%s' by id: %v. Trying to get security group by name", securityGroup, err))

			resolvedSecurityGroup, err = s.resolveSecurityGroupByName(securityGroup)
			if err != nil {
				return []string{}, fmt.Errorf("failed to get security group '%s' by name: %w", securityGroup, err)
			}
		}

		if resolvedSecurityGroup == nil {
			return []string{}, fmt.Errorf("could not resolve security group '%s'", securityGroup)
		}

		securityGroupIds = append(securityGroupIds, resolvedSecurityGroup.ID)
	}
	return securityGroupIds, nil
}

func (s securityGroupsResolver) resolveSecurityGroupById(securityGroupID string) (*groups.SecGroup, error) {
	return s.networkingFacade.GetSecurityGroups(s.serviceClients.RetryableServiceClient, securityGroupID)
}

func (s securityGroupsResolver) resolveSecurityGroupByName(securityGroupName string) (*groups.SecGroup, error) {
	listOpts := groups.ListOpts{
		Name: securityGroupName,
	}

	allPages, err := s.networkingFacade.ListSecurityGroups(s.serviceClients.RetryableServiceClient, listOpts)
	if err != nil {
		return nil, fmt.Errorf("failed to list security groups: %w", err)
	}

	allSecurityGroups, err := s.networkingFacade.ExtractSecurityGroups(allPages)
	if err != nil {
		return nil, fmt.Errorf("failed to extract security groups: %w", err)
	}

	if len(allSecurityGroups) == 0 {
		return nil, fmt.Errorf("security group '%s' could not be found", securityGroupName)
	}

	return &allSecurityGroups[0], nil
}
