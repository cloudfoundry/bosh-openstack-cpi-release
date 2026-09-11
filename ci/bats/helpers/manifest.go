package helpers

import (
	"fmt"
	"strings"
)

// CloudConfig generates a BOSH cloud config from the BATs configuration.
// It creates two manual networks (primary + secondary), two VM types
// (default / no-ephemeral-disk), one disk type, and a compilation block.
func CloudConfig(cfg *Config) string {
	primary := cfg.PrimaryNetwork()
	az := cfg.BATs.AvailabilityZone
	if az == "" {
		az = "nova"
	}

	reserved := yamlSeq(primary.Reserved, "    ")
	static := yamlSeq(primary.Static, "    ")

	var sb strings.Builder
	fmt.Fprintf(&sb, `azs:
- name: z1
  cloud_properties:
    availability_zone: %s

vm_types:
- name: default
  cloud_properties:
    instance_type: %s
- name: no-ephemeral-disk
  cloud_properties:
    instance_type: %s

disk_types:
- name: default
  disk_size: 2048
  cloud_properties: {}

networks:
- name: default
  type: manual
  subnets:
  - range: %s
    gateway: %s
    az: z1
    dns: [8.8.8.8]
    reserved:
%s
    static:
%s
    cloud_properties:
      net_id: %s
      security_groups: [%s]
`,
		az,
		cfg.BATs.InstanceType,
		cfg.BATs.FlavorWithNoEphemeralDisk,
		primary.CIDR,
		primary.Gateway,
		reserved,
		static,
		primary.CloudProps.NetID,
		strings.Join(primary.CloudProps.SecurityGroups, ", "),
	)

	if secondary, ok := cfg.SecondaryNetwork(); ok {
		secReserved := yamlSeq(secondary.Reserved, "    ")
		secStatic := yamlSeq(secondary.Static, "    ")
		fmt.Fprintf(&sb, `- name: second
  type: manual
  subnets:
  - range: %s
    gateway: %s
    az: z1
    dns: [8.8.8.8]
    reserved:
%s
    static:
%s
    cloud_properties:
      net_id: %s
      security_groups: [%s]
`,
			secondary.CIDR,
			secondary.Gateway,
			secReserved,
			secStatic,
			secondary.CloudProps.NetID,
			strings.Join(secondary.CloudProps.SecurityGroups, ", "),
		)
	}

	fmt.Fprintf(&sb, `
compilation:
  workers: 2
  reuse_compilation_vms: true
  az: z1
  vm_type: default
  network: default
`)
	return sb.String()
}

// VMLifecycleManifest returns a minimal deployment manifest that deploys one
// agent-only VM on the primary manual network at staticIP.
func VMLifecycleManifest(cfg *Config, name, staticIP string) string {
	return vmManifest(cfg, name, staticIP, "default", false)
}

// PersistentDiskManifest is like VMLifecycleManifest but attaches a 2 GiB
// persistent disk so BOSH will manage disk attach/detach across recreates.
func PersistentDiskManifest(cfg *Config, name, staticIP string) string {
	return vmManifest(cfg, name, staticIP, "default", true)
}

// MultiNetworkManifest deploys two VMs on the same deployment, one per manual
// network, using the supplied static IPs.
func MultiNetworkManifest(_ *Config, name, primaryIP, secondaryIP string) string {
	return fmt.Sprintf(`name: %s
stemcells:
- alias: default
  os: ubuntu-noble
  version: latest
instance_groups:
- name: primary-vm
  instances: 1
  vm_type: default
  stemcell: default
  azs: [z1]
  networks:
  - name: default
    static_ips: [%s]
    default: [dns, gateway]
  jobs: []
- name: secondary-vm
  instances: 1
  vm_type: default
  stemcell: default
  azs: [z1]
  networks:
  - name: second
    static_ips: [%s]
  jobs: []
update:
  canaries: 1
  max_in_flight: 2
  canary_watch_time: 30000-600000
  update_watch_time: 30000-600000
`, name, primaryIP, secondaryIP)
}

func vmManifest(cfg *Config, name, staticIP, vmType string, persistentDisk bool) string {
	diskLine := ""
	if persistentDisk {
		diskLine = "\n  persistent_disk_type: default"
	}
	return fmt.Sprintf(`name: %s
stemcells:
- alias: default
  os: ubuntu-noble
  version: latest
instance_groups:
- name: bats-vm
  instances: 1
  vm_type: %s
  stemcell: default
  azs: [z1]%s
  networks:
  - name: default
    static_ips: [%s]
    default: [dns, gateway]
  jobs: []
update:
  canaries: 1
  max_in_flight: 1
  canary_watch_time: 30000-600000
  update_watch_time: 30000-600000
`, name, vmType, diskLine, staticIP)
}

// yamlSeq renders a []string as an indented YAML sequence suitable for
// embedding inside a larger YAML document at the given indent level.
func yamlSeq(items []string, indent string) string {
	if len(items) == 0 {
		return indent + "[]"
	}
	var lines []string
	for _, item := range items {
		lines = append(lines, indent+"- "+item)
	}
	return strings.Join(lines, "\n")
}
