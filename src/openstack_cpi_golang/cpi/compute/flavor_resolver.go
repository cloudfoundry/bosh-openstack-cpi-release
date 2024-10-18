package compute

import (
	"fmt"
	"math"
	"sort"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/flavors"
)

const NoDisk = 0

//counterfeiter:generate . FlavorResolver
type FlavorResolver interface {
	ResolveFlavorForInstanceType(flavorName string) (flavors.Flavor, error)
	ResolveFlavorForRequirements(vmResources apiv1.VMResources, bootFromVolume bool) ([]flavors.Flavor, error)
	GetClosestMatchedFlavor(possibleFlavors []flavors.Flavor) flavors.Flavor
	GetFlavorById(flavorId string) (flavors.Flavor, error)
}

type flavorResolver struct {
	serviceClients utils.ServiceClients
	computeFacade  ComputeFacade
}

func NewFlavorResolver(
	serviceClients utils.ServiceClients,
	computeFacade ComputeFacade,
) flavorResolver {
	return flavorResolver{
		serviceClients: serviceClients,
		computeFacade:  computeFacade,
	}
}

func (f flavorResolver) GetFlavorById(flavorId string) (flavors.Flavor, error) {
	allFlavors, err := f.getFlavors()
	if err != nil {
		return flavors.Flavor{}, fmt.Errorf("failed to get flavors: %w", err)
	}

	var flavor *flavors.Flavor
	for _, singleFlavor := range allFlavors {
		if singleFlavor.ID == flavorId {
			flavor = &singleFlavor
			break
		}
	}

	if flavor == nil {
		return flavors.Flavor{}, fmt.Errorf("flavor for id '%s' not found", flavorId)
	}

	return *flavor, nil
}

func (f flavorResolver) ResolveFlavorForInstanceType(instanceType string) (flavors.Flavor, error) {
	allFlavors, err := f.getFlavors()
	if err != nil {
		return flavors.Flavor{}, fmt.Errorf("failed to get flavors: %w", err)
	}

	var flavor *flavors.Flavor
	for _, singleFlavor := range allFlavors {
		if singleFlavor.Name == instanceType {
			flavor = &singleFlavor
			break
		}
	}

	if flavor == nil {
		return flavors.Flavor{}, fmt.Errorf("flavor for instance type '%s' not found", instanceType)
	}

	if flavor.Ephemeral > 0 {
		// Ephemeral disk size should be at least the double of the vm total memory size, as agent will need:
		// - vm total memory size for swapon,
		// - the rest for /var/vcap/data
		minEphemeralSize := (flavor.RAM / 1024) * 2
		if flavor.Ephemeral < minEphemeralSize {
			return flavors.Flavor{}, fmt.Errorf("flavor '%s' should have at least %dGb of ephemeral disk", flavor.Name, minEphemeralSize)
		}
	}

	return *flavor, nil
}

func (f flavorResolver) ResolveFlavorForRequirements(vmResources apiv1.VMResources, bootFromVolume bool) ([]flavors.Flavor, error) {
	normalizedEphemeralDiskSize := float64(vmResources.EphemeralDiskSize) / 1024

	allFlavors, err := f.getFlavors()
	if err != nil {
		return []flavors.Flavor{}, fmt.Errorf("failed to get flavors: %w", err)
	}

	var validFlavors []flavors.Flavor
	for _, singleFlavor := range allFlavors {
		if singleFlavor.RAM >= vmResources.RAM && singleFlavor.VCPUs >= vmResources.CPU {
			validFlavors = append(validFlavors, singleFlavor)
		}
	}

	var possibleFlavors []flavors.Flavor
	if bootFromVolume {
		for _, singleFlavor := range validFlavors {
			if singleFlavor.Ephemeral == NoDisk {
				possibleFlavors = append(possibleFlavors, singleFlavor)
			}
		}
	} else {
		possibleFlavors = f.bootDefaultFlavors(int(math.Ceil(normalizedEphemeralDiskSize)), validFlavors)
	}
	return possibleFlavors, nil
}

func (f flavorResolver) GetClosestMatchedFlavor(possibleFlavors []flavors.Flavor) flavors.Flavor {
	// sort the flavors by vcpus, ram, disk and ephemeral disk
	// the first element is the closest match
	sort.Slice(possibleFlavors, func(i, j int) bool {
		if possibleFlavors[i].VCPUs != possibleFlavors[j].VCPUs {
			return possibleFlavors[i].VCPUs < possibleFlavors[j].VCPUs
		}
		if possibleFlavors[i].RAM != possibleFlavors[j].RAM {
			return possibleFlavors[i].RAM < possibleFlavors[j].RAM
		}
		if (possibleFlavors[i].Disk + possibleFlavors[i].Ephemeral) != (possibleFlavors[j].Disk + possibleFlavors[j].Ephemeral) {
			return (possibleFlavors[i].Disk + possibleFlavors[i].Ephemeral) < (possibleFlavors[j].Disk + possibleFlavors[j].Ephemeral)
		}
		return possibleFlavors[i].Disk < possibleFlavors[j].Disk
	})

	// After sorting, the first element is the closest match
	return possibleFlavors[0]
}

func (f flavorResolver) getFlavors() ([]flavors.Flavor, error) {
	flavorPages, err := f.computeFacade.ListFlavors(f.serviceClients.RetryableServiceClient, flavors.ListOpts{})
	if err != nil {
		return []flavors.Flavor{}, fmt.Errorf("failed to list flavors: %w", err)
	}

	allFlavors, err := f.computeFacade.ExtractFlavors(flavorPages)
	if err != nil {
		return []flavors.Flavor{}, fmt.Errorf("failed to extract flavors: %w", err)
	}

	return allFlavors, nil
}

func (f flavorResolver) bootDefaultFlavors(ephemeralDiskSize int, validFlavors []flavors.Flavor) []flavors.Flavor {
	var resultFlavors []flavors.Flavor
	for _, singleFlavor := range validFlavors {
		if singleFlavor.Ephemeral >= ephemeralDiskSize && singleFlavor.Disk >= properties.OsOverheadInGb {
			resultFlavors = append(resultFlavors, singleFlavor)
		}
	}

	if len(resultFlavors) != 0 {
		return resultFlavors
	}

	for _, singleFlavor := range validFlavors {
		if singleFlavor.Ephemeral == NoDisk && singleFlavor.Disk >= ephemeralDiskSize+properties.OsOverheadInGb {
			resultFlavors = append(resultFlavors, singleFlavor)
		}
	}
	return resultFlavors
}
