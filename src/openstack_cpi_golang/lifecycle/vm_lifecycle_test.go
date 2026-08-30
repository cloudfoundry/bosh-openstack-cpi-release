//go:build lifecycle

package lifecycle_test

import (
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/gophercloud/gophercloud"
	"github.com/gophercloud/gophercloud/openstack"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/extensions/volumeattach"
	"github.com/gophercloud/gophercloud/openstack/compute/v2/servers"
	"github.com/gophercloud/gophercloud/openstack/networking/v2/extensions/security/groups"
	"github.com/gophercloud/gophercloud/openstack/networking/v2/ports"
	"github.com/gophercloud/gophercloud/openstack/networking/v2/subnets"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("VM lifecycle (CPI-level)", func() {

	Describe("networking variations", func() {
		It("creates a VM across multiple manual networks with config_drive", func() {
			cfg := baseConfig(withConfigDrive("cdrom"), withUseDHCP(false))
			networks := map[string]interface{}{
				"default": map[string]interface{}{
					"type": "manual",
					"ip":   mustEnv("BOSH_OPENSTACK_MANUAL_IP"),
					"cloud_properties": map[string]interface{}{
						"net_id": mustEnv("BOSH_OPENSTACK_NET_ID"),
					},
				},
				"second": map[string]interface{}{
					"type":     "manual",
					"ip":       mustEnv("BOSH_OPENSTACK_NO_DHCP_MANUAL_IP_1"),
					"use_dhcp": false,
					"cloud_properties": map[string]interface{}{
						"net_id": mustEnv("BOSH_OPENSTACK_NET_ID_NO_DHCP_1"),
					},
				},
			}
			vmID, cpiErr := createVM(cfg, stemcellID, defaultResourcePool(), networks, nil, nil)
			Expect(cpiErr).To(BeNil())

			netIDs := serverPortNetworkIDs(cfg, vmID)
			Expect(netIDs).To(ContainElement(mustEnv("BOSH_OPENSTACK_NET_ID")))
			Expect(netIDs).To(ContainElement(mustEnv("BOSH_OPENSTACK_NET_ID_NO_DHCP_1")))
		})

		It("adds allowed_address_pairs (VRRP) to the port", func() {
			cfg := baseConfig()
			vrrpIP := mustEnv("BOSH_OPENSTACK_ALLOWED_ADDRESS_PAIRS")
			resourcePool := defaultResourcePool()
			resourcePool["allowed_address_pairs"] = vrrpIP

			manualIP := mustEnv("BOSH_OPENSTACK_MANUAL_IP")
			_, cpiErr := createVM(cfg, stemcellID, resourcePool, manualNetwork(), nil, nil)
			Expect(cpiErr).To(BeNil())

			port := findPortByIP(cfg, manualIP)
			Expect(port).ToNot(BeNil())
			pairs := []string{}
			for _, p := range port.AllowedAddressPairs {
				pairs = append(pairs, p.IPAddress)
			}
			Expect(pairs).To(ContainElement(vrrpIP))
		})

		It("creates a VM when a neutron port already exists for the IP", func() {
			cfg := baseConfig()
			manualIP := mustEnv("BOSH_OPENSTACK_MANUAL_IP")
			preCreatePort(cfg, manualIP)

			vmID, cpiErr := createVM(cfg, stemcellID, defaultResourcePool(), manualNetwork(), nil, nil)
			Expect(cpiErr).To(BeNil())
			exists, _ := hasVM(cfg, vmID)
			Expect(exists).To(BeTrue())
		})

		It("creates a VM with use_nova_networking", func() {
			cfg := baseConfig(withUseNovaNetworking())
			vmID, cpiErr := createVM(cfg, stemcellID, defaultResourcePool(), dynamicNetwork(), nil, nil)
			Expect(cpiErr).To(BeNil())
			exists, _ := hasVM(cfg, vmID)
			Expect(exists).To(BeTrue())
		})
	})

	Describe("security groups", func() {
		It("creates a VM with a security group specified by name", func() {
			cfg := baseConfig()
			sgName := mustEnv("BOSH_OPENSTACK_SECURITY_GROUP_NAME")
			networks := networkWithSecurityGroups(map[string]interface{}{
				"net_id":          mustEnv("BOSH_OPENSTACK_NET_ID"),
				"security_groups": []string{sgName},
			})
			vmID, cpiErr := createVM(cfg, stemcellID, defaultResourcePool(), networks, nil, nil)
			Expect(cpiErr).To(BeNil())
			Expect(serverPortSecurityGroups(cfg, vmID)).To(ContainElement(securityGroupID(cfg, sgName)))
		})

		It("creates a VM with a security group specified by id", func() {
			cfg := baseConfig()
			sgID := mustEnv("BOSH_OPENSTACK_SECURITY_GROUP_ID")
			networks := networkWithSecurityGroups(map[string]interface{}{
				"net_id":          mustEnv("BOSH_OPENSTACK_NET_ID"),
				"security_groups": []string{sgID},
			})
			vmID, cpiErr := createVM(cfg, stemcellID, defaultResourcePool(), networks, nil, nil)
			Expect(cpiErr).To(BeNil())
			Expect(serverPortSecurityGroups(cfg, vmID)).To(ContainElement(sgID))
		})
	})

	Describe("boot from volume", func() {
		It("boots from a volume attached at /dev/vda", func() {
			cfg := baseConfig(withBootFromVolume())
			vmID, cpiErr := createVM(cfg, stemcellID, defaultResourcePool(), dynamicNetwork(), nil, nil)
			Expect(cpiErr).To(BeNil())
			Expect(serverAttachmentDevices(cfg, vmID)).To(ContainElement("/dev/vda"))
		})

		It("boots from a volume when boot_from_volume is set in cloud_properties", func() {
			cfg := baseConfig()
			resourcePool := defaultResourcePool()
			resourcePool["boot_from_volume"] = true
			vmID, cpiErr := createVM(cfg, stemcellID, resourcePool, dynamicNetwork(), nil, nil)
			Expect(cpiErr).To(BeNil())
			Expect(serverAttachmentDevices(cfg, vmID)).To(ContainElement("/dev/vda"))
		})

		It("boots from a volume with a zero-root-disk flavor and an explicit root_disk size", func() {
			cfg := baseConfig(withBootFromVolume())
			resourcePool := map[string]interface{}{
				"instance_type": mustEnv("BOSH_OPENSTACK_FLAVOR_WITH_NO_ROOT_DISK"),
				"root_disk":     map[string]interface{}{"size": 20},
			}
			if az := getEnv("BOSH_OPENSTACK_AVAILABILITY_ZONE", ""); az != "" {
				resourcePool["availability_zone"] = az
			}
			vmID, cpiErr := createVM(cfg, stemcellID, resourcePool, dynamicNetwork(), nil, nil)
			Expect(cpiErr).To(BeNil())
			Expect(serverAttachmentDevices(cfg, vmID)).To(ContainElement("/dev/vda"))
		})

		It("fails with a zero-root-disk flavor and no root_disk size", func() {
			cfg := baseConfig(withBootFromVolume())
			resourcePool := map[string]interface{}{
				"instance_type": mustEnv("BOSH_OPENSTACK_FLAVOR_WITH_NO_ROOT_DISK"),
			}
			_, cpiErr := createVM(cfg, stemcellID, resourcePool, dynamicNetwork(), nil, nil)
			Expect(cpiErr).ToNot(BeNil())
		})
	})

	Describe("naming and metadata", func() {
		It("sets a human-readable server name from metadata", func() {
			cfg := baseConfig(withHumanReadableVMNames())
			vmID, cpiErr := createVM(cfg, stemcellID, defaultResourcePool(), dynamicNetwork(), nil, nil)
			Expect(cpiErr).To(BeNil())

			Expect(setVMMetadata(cfg, vmID, map[string]interface{}{
				"job":   "some-job",
				"index": "0",
				"name":  "openstack_cpi_spec/instance_id",
			})).To(BeNil())

			Expect(getServer(cfg, vmID).Name).To(Equal("openstack_cpi_spec/instance_id"))
		})
	})

	Describe("error handling", func() {
		It("fails to create a VM in a non-existent availability zone", func() {
			cfg := baseConfig()
			resourcePool := map[string]interface{}{
				"instance_type":     getEnv("BOSH_OPENSTACK_INSTANCE_TYPE", "m1.small"),
				"availability_zone": "fake-availability-zone",
			}
			_, cpiErr := createVM(cfg, stemcellID, resourcePool, dynamicNetwork(), nil, nil)
			Expect(cpiErr).ToNot(BeNil())
		})

		It("fails to create a VM with a bogus net_id", func() {
			cfg := baseConfig()
			networks := map[string]interface{}{
				"default": map[string]interface{}{
					"type": "dynamic",
					"cloud_properties": map[string]interface{}{
						"net_id": "00000000-0000-0000-0000-000000000000",
					},
				},
			}
			_, cpiErr := createVM(cfg, stemcellID, defaultResourcePool(), networks, nil, nil)
			Expect(cpiErr).ToNot(BeNil())
		})

		It("does not fail when detaching a non-existent disk", func() {
			cfg := baseConfig()
			vmID, cpiErr := createVM(cfg, stemcellID, defaultResourcePool(), dynamicNetwork(), nil, nil)
			Expect(cpiErr).To(BeNil())
			Expect(detachDisk(cfg, vmID, "non-existing-disk")).To(BeNil())
		})
	})
})

func networkWithSecurityGroups(cloudProps map[string]interface{}) map[string]interface{} {
	return map[string]interface{}{
		"default": map[string]interface{}{
			"type":             "dynamic",
			"cloud_properties": cloudProps,
		},
	}
}

func computeClient(cfg config.CpiConfig) *gophercloud.ServiceClient {
	GinkgoHelper()
	provider, err := openstack.AuthenticatedClient(cfg.OpenStackConfig().AuthOptions())
	Expect(err).NotTo(HaveOccurred())
	client, err := openstack.NewComputeV2(provider, gophercloud.EndpointOpts{Region: cfg.OpenStackConfig().Region})
	Expect(err).NotTo(HaveOccurred())
	return client
}

func networkClient(cfg config.CpiConfig) *gophercloud.ServiceClient {
	GinkgoHelper()
	provider, err := openstack.AuthenticatedClient(cfg.OpenStackConfig().AuthOptions())
	Expect(err).NotTo(HaveOccurred())
	client, err := openstack.NewNetworkV2(provider, gophercloud.EndpointOpts{Region: cfg.OpenStackConfig().Region})
	Expect(err).NotTo(HaveOccurred())
	return client
}

func getServer(cfg config.CpiConfig, id string) *servers.Server {
	GinkgoHelper()
	srv, err := servers.Get(computeClient(cfg), id).Extract()
	Expect(err).NotTo(HaveOccurred())
	return srv
}

func serverAttachmentDevices(cfg config.CpiConfig, id string) []string {
	GinkgoHelper()
	pages, err := volumeattach.List(computeClient(cfg), id).AllPages()
	Expect(err).NotTo(HaveOccurred())
	attachments, err := volumeattach.ExtractVolumeAttachments(pages)
	Expect(err).NotTo(HaveOccurred())
	devices := []string{}
	for _, a := range attachments {
		devices = append(devices, a.Device)
	}
	return devices
}

func serverPortNetworkIDs(cfg config.CpiConfig, vmID string) []string {
	GinkgoHelper()
	netIDs := []string{}
	for _, p := range serverPorts(cfg, vmID) {
		netIDs = append(netIDs, p.NetworkID)
	}
	return netIDs
}

func serverPortSecurityGroups(cfg config.CpiConfig, vmID string) []string {
	GinkgoHelper()
	sgs := []string{}
	for _, p := range serverPorts(cfg, vmID) {
		sgs = append(sgs, p.SecurityGroups...)
	}
	return sgs
}

func serverPorts(cfg config.CpiConfig, vmID string) []ports.Port {
	GinkgoHelper()
	pages, err := ports.List(networkClient(cfg), ports.ListOpts{DeviceID: vmID}).AllPages()
	Expect(err).NotTo(HaveOccurred())
	found, err := ports.ExtractPorts(pages)
	Expect(err).NotTo(HaveOccurred())
	return found
}

func securityGroupID(cfg config.CpiConfig, name string) string {
	GinkgoHelper()
	pages, err := groups.List(networkClient(cfg), groups.ListOpts{Name: name}).AllPages()
	Expect(err).NotTo(HaveOccurred())
	found, err := groups.ExtractGroups(pages)
	Expect(err).NotTo(HaveOccurred())
	Expect(found).ToNot(BeEmpty(), "security group %q not found", name)
	return found[0].ID
}

func findPortByIP(cfg config.CpiConfig, ip string) *ports.Port {
	GinkgoHelper()
	pages, err := ports.List(networkClient(cfg), ports.ListOpts{FixedIPs: []ports.FixedIPOpts{{IPAddress: ip}}}).AllPages()
	Expect(err).NotTo(HaveOccurred())
	found, err := ports.ExtractPorts(pages)
	Expect(err).NotTo(HaveOccurred())
	if len(found) == 0 {
		return nil
	}
	return &found[0]
}

func preCreatePort(cfg config.CpiConfig, ip string) {
	GinkgoHelper()
	client := networkClient(cfg)
	netID := mustEnv("BOSH_OPENSTACK_NET_ID")
	port, err := ports.Create(client, ports.CreateOpts{
		NetworkID:      netID,
		FixedIPs:       []ports.IP{{SubnetID: subnetIDForNetwork(cfg, netID), IPAddress: ip}},
		SecurityGroups: &[]string{mustEnv("BOSH_OPENSTACK_SECURITY_GROUP_ID")},
	}).Extract()
	Expect(err).NotTo(HaveOccurred())
	DeferCleanup(func() { _ = ports.Delete(client, port.ID).ExtractErr() })
}

// SubnetID has no omitempty in gophercloud, so an empty value is rejected.
func subnetIDForNetwork(cfg config.CpiConfig, netID string) string {
	GinkgoHelper()
	pages, err := subnets.List(networkClient(cfg), subnets.ListOpts{NetworkID: netID}).AllPages()
	Expect(err).NotTo(HaveOccurred())
	found, err := subnets.ExtractSubnets(pages)
	Expect(err).NotTo(HaveOccurred())
	Expect(found).ToNot(BeEmpty(), "network %s has no subnets", netID)
	return found[0].ID
}
