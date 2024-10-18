package compute

import (
	"math/rand"
	"time"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
)

//counterfeiter:generate . AvailabilityZoneProvider
type AvailabilityZoneProvider interface {
	GetAvailabilityZones(cloudProperties properties.CreateVM) []string
}

type availabilityZoneProvider struct {
}

func NewAvailabilityZoneProvider() availabilityZoneProvider {
	return availabilityZoneProvider{}
}

func (a availabilityZoneProvider) GetAvailabilityZones(cloudProperties properties.CreateVM) []string {

	if len(cloudProperties.AvailabilityZones) > 0 {
		return a.shuffleAZs(cloudProperties)
	}

	return []string{cloudProperties.AvailabilityZone}
}

func (a availabilityZoneProvider) shuffleAZs(cloudProperties properties.CreateVM) []string {
	shuffledZones := cloudProperties.AvailabilityZones
	r := rand.New(rand.NewSource(time.Now().UnixNano()))

	r.Shuffle(len(shuffledZones), func(i, j int) {
		shuffledZones[i], shuffledZones[j] = shuffledZones[j], shuffledZones[i]
	})
	return shuffledZones
}
