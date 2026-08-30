//go:build lifecycle

// Package lifecycle_test holds real-OpenStack lifecycle tests, gated behind the
// `lifecycle` build tag and configured from BOSH_OPENSTACK_* env vars.
package lifecycle_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"testing"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	boshlog "github.com/cloudfoundry/bosh-utils/logger"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	yaml "go.yaml.in/yaml/v3"
)

func TestLifecycle(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "OpenStack Lifecycle Suite")
}

var logger = utils.NewLogger(boshlog.NewWriterLogger(boshlog.LevelError, os.Stderr))

// stemcellID is uploaded once and reused by specs needing a bootable image.
var stemcellID string

var suiteManifest stemcellManifest

var _ = BeforeSuite(func() {
	suiteManifest = readStemcellManifest()
	id, cpiErr := createStemcell(baseConfig(), stemcellImagePath(), suiteManifest.CloudProperties)
	Expect(cpiErr).To(BeNil(), "failed to upload suite stemcell: %v", cpiErr)
	stemcellID = id
})

var _ = AfterSuite(func() {
	if stemcellID != "" {
		_ = deleteStemcellBestEffort(baseConfig(), stemcellID)
	}
})

type stemcellManifest struct {
	Name            string                 `yaml:"name"`
	Version         string                 `yaml:"version"`
	CloudProperties map[string]interface{} `yaml:"cloud_properties"`
}

func stemcellDir() string       { return mustEnv("BOSH_OPENSTACK_STEMCELL_PATH") }
func stemcellImagePath() string { return filepath.Join(stemcellDir(), "image") }

func readStemcellManifest() stemcellManifest {
	GinkgoHelper()
	data, err := os.ReadFile(filepath.Join(stemcellDir(), "stemcell.MF"))
	Expect(err).NotTo(HaveOccurred())
	var mf stemcellManifest
	Expect(yaml.Unmarshal(data, &mf)).To(Succeed())
	Expect(mf.CloudProperties).ToNot(BeEmpty(), "stemcell.MF has no cloud_properties")
	return mf
}

type configOverride func(*config.OpenstackConfig)

func baseConfig(overrides ...configOverride) config.CpiConfig {
	var cfg config.CpiConfig
	os := &cfg.Cloud.Properties.Openstack

	os.AuthURL = mustEnv("BOSH_OPENSTACK_AUTH_URL_V3")
	os.Username = mustEnv("BOSH_OPENSTACK_USERNAME_V3")
	os.APIKey = mustEnv("BOSH_OPENSTACK_API_KEY_V3")
	os.DomainName = mustEnv("BOSH_OPENSTACK_DOMAIN")
	os.ProjectName = mustEnv("BOSH_OPENSTACK_PROJECT")

	os.DefaultKeyName = getEnv("BOSH_OPENSTACK_DEFAULT_KEY_NAME", "")
	// The project "default" security group is not reliably bootable on the CI
	// DevStack; use the terraform-created group, as BATS does.
	os.DefaultSecurityGroups = []string{getEnv("BOSH_OPENSTACK_SECURITY_GROUP_NAME", "default")}
	os.EndpointType = "publicURL"
	os.WaitResourcePollInterval = 5
	os.StateTimeOut = getEnvInt("BOSH_OPENSTACK_STATE_TIMEOUT", 300)
	os.StemcellPubliclyVisible = false
	os.VM.Stemcell.APIVersion = 2
	if region := getEnv("BOSH_OPENSTACK_REGION", ""); region != "" {
		os.Region = region
	}
	if volType := getEnv("BOSH_OPENSTACK_VOLUME_TYPE", ""); volType != "" {
		os.DefaultVolumeType = volType
	}

	cfg.Cloud.Properties.RetryConfig = config.RetryConfigMap{
		"default": {MaxAttempts: 10, SleepDuration: 3},
	}

	for _, o := range overrides {
		o(os)
	}
	return cfg
}

func withBootFromVolume() configOverride {
	return func(o *config.OpenstackConfig) { o.BootFromVolume = true }
}

func withConfigDrive(kind string) configOverride {
	return func(o *config.OpenstackConfig) { o.ConfigDrive = kind }
}

func withUseDHCP(v bool) configOverride {
	return func(o *config.OpenstackConfig) { o.UseDHCP = v }
}

func withHumanReadableVMNames() configOverride {
	return func(o *config.OpenstackConfig) { o.HumanReadableVMNames = true }
}

func withUseNovaNetworking() configOverride {
	return func(o *config.OpenstackConfig) { o.UseNovaNetworking = true }
}

func withDefaultVolumeType(t string) configOverride {
	return func(o *config.OpenstackConfig) { o.DefaultVolumeType = t }
}

type cpiError struct {
	Type      string `json:"type"`
	Message   string `json:"message"`
	OkToRetry bool   `json:"ok_to_retry"`
}

func (e *cpiError) String() string {
	if e == nil {
		return "<nil>"
	}
	return fmt.Sprintf("%s: %s", e.Type, e.Message)
}

type cpiEnvelope struct {
	Result json.RawMessage `json:"result"`
	Error  *cpiError       `json:"error"`
	Log    string          `json:"log"`
}

// execCPI drives cpi.Execute like the production binary: a JSON request on
// os.Stdin, the JSON response captured from os.Stdout, restored per call.
func execCPI(cfg config.CpiConfig, method string, args ...interface{}) cpiEnvelope {
	GinkgoHelper()

	reqBytes, err := json.Marshal(map[string]interface{}{
		"method":      method,
		"arguments":   args,
		"api_version": 2,
	})
	Expect(err).NotTo(HaveOccurred())

	origStdin, origStdout := os.Stdin, os.Stdout
	defer func() { os.Stdin, os.Stdout = origStdin, origStdout }()

	inR, inW, err := os.Pipe()
	Expect(err).NotTo(HaveOccurred())
	defer func() { _ = inR.Close() }()
	os.Stdin = inR
	go func() {
		_, _ = inW.Write(reqBytes)
		_ = inW.Close()
	}()

	outR, outW, err := os.Pipe()
	Expect(err).NotTo(HaveOccurred())
	defer func() { _ = outR.Close() }()
	os.Stdout = outW
	outCh := make(chan string, 1)
	go func() {
		var b bytes.Buffer
		_, _ = io.Copy(&b, outR)
		outCh <- b.String()
	}()

	execErr := cpi.Execute(cfg, logger)
	_ = outW.Close()
	raw := <-outCh

	Expect(execErr).NotTo(HaveOccurred(), "cpi.Execute failed for %s: %v (raw: %s)", method, execErr, raw)

	var env cpiEnvelope
	Expect(json.Unmarshal([]byte(raw), &env)).To(Succeed(), "unparseable response for %s: %s", method, raw)
	return env
}

func resultString(env cpiEnvelope) string {
	if len(env.Result) == 0 || string(env.Result) == "null" {
		return ""
	}
	var s string
	Expect(json.Unmarshal(env.Result, &s)).To(Succeed(), "result not a string: %s", env.Result)
	return s
}

// ---------------------------------------------------------------------------
// Typed method wrappers (register best-effort cleanup on success)
// ---------------------------------------------------------------------------

func createStemcell(cfg config.CpiConfig, imagePath string, cloudProps map[string]interface{}) (string, *cpiError) {
	env := execCPI(cfg, "create_stemcell", imagePath, cloudProps)
	return resultString(env), env.Error
}

func deleteStemcell(cfg config.CpiConfig, id string) *cpiError {
	return execCPI(cfg, "delete_stemcell", id).Error
}

func deleteStemcellBestEffort(cfg config.CpiConfig, id string) error {
	if err := execCPI(cfg, "delete_stemcell", id).Error; err != nil {
		return fmt.Errorf("%s", err.String())
	}
	return nil
}

// createVM returns the VM cid and registers best-effort cleanup on success.
func createVM(cfg config.CpiConfig, stemcell string, cloudProps map[string]interface{}, networks map[string]interface{}, diskLocality []string, env map[string]interface{}) (string, *cpiError) {
	if env == nil {
		env = map[string]interface{}{"bosh": map[string]interface{}{"group": "instance-group-1"}}
	}
	if diskLocality == nil {
		diskLocality = []string{}
	}
	resp := execCPI(cfg, "create_vm", "agent-007", stemcell, cloudProps, networks, diskLocality, env)
	if resp.Error != nil {
		return "", resp.Error
	}
	// v2 create_vm returns [vm_cid, network_settings].
	var tuple []json.RawMessage
	Expect(json.Unmarshal(resp.Result, &tuple)).To(Succeed(), "create_vm result not a tuple: %s", resp.Result)
	Expect(tuple).ToNot(BeEmpty())
	var cid string
	Expect(json.Unmarshal(tuple[0], &cid)).To(Succeed())
	DeferCleanup(func() { _ = deleteVMBestEffort(cfg, cid) })
	return cid, nil
}

func deleteVM(cfg config.CpiConfig, vmID string) *cpiError {
	return execCPI(cfg, "delete_vm", vmID).Error
}

func deleteVMBestEffort(cfg config.CpiConfig, vmID string) error {
	if err := execCPI(cfg, "delete_vm", vmID).Error; err != nil {
		return fmt.Errorf("%s", err.String())
	}
	return nil
}

func hasVM(cfg config.CpiConfig, vmID string) (bool, *cpiError) {
	env := execCPI(cfg, "has_vm", vmID)
	if env.Error != nil {
		return false, env.Error
	}
	var b bool
	Expect(json.Unmarshal(env.Result, &b)).To(Succeed())
	return b, nil
}

func setVMMetadata(cfg config.CpiConfig, vmID string, metadata map[string]interface{}) *cpiError {
	return execCPI(cfg, "set_vm_metadata", vmID, metadata).Error
}

func createDisk(cfg config.CpiConfig, sizeMB int, cloudProps map[string]interface{}, vmID string) (string, *cpiError) {
	if cloudProps == nil {
		cloudProps = map[string]interface{}{}
	}
	env := execCPI(cfg, "create_disk", sizeMB, cloudProps, vmID)
	if env.Error != nil {
		return "", env.Error
	}
	id := resultString(env)
	DeferCleanup(func() { _ = deleteDiskBestEffort(cfg, id) })
	return id, nil
}

func deleteDisk(cfg config.CpiConfig, diskID string) *cpiError {
	return execCPI(cfg, "delete_disk", diskID).Error
}

func deleteDiskBestEffort(cfg config.CpiConfig, diskID string) error {
	if err := execCPI(cfg, "delete_disk", diskID).Error; err != nil {
		return fmt.Errorf("%s", err.String())
	}
	return nil
}

func hasDisk(cfg config.CpiConfig, diskID string) (bool, *cpiError) {
	env := execCPI(cfg, "has_disk", diskID)
	if env.Error != nil {
		return false, env.Error
	}
	var b bool
	Expect(json.Unmarshal(env.Result, &b)).To(Succeed())
	return b, nil
}

func attachDisk(cfg config.CpiConfig, vmID, diskID string) *cpiError {
	return execCPI(cfg, "attach_disk", vmID, diskID).Error
}

func detachDisk(cfg config.CpiConfig, vmID, diskID string) *cpiError {
	return execCPI(cfg, "detach_disk", vmID, diskID).Error
}

func snapshotDisk(cfg config.CpiConfig, diskID string, metadata map[string]interface{}) (string, *cpiError) {
	if metadata == nil {
		metadata = map[string]interface{}{}
	}
	env := execCPI(cfg, "snapshot_disk", diskID, metadata)
	if env.Error != nil {
		return "", env.Error
	}
	id := resultString(env)
	DeferCleanup(func() { _ = deleteSnapshotBestEffort(cfg, id) })
	return id, nil
}

func deleteSnapshot(cfg config.CpiConfig, snapshotID string) *cpiError {
	return execCPI(cfg, "delete_snapshot", snapshotID).Error
}

func deleteSnapshotBestEffort(cfg config.CpiConfig, snapshotID string) error {
	if err := execCPI(cfg, "delete_snapshot", snapshotID).Error; err != nil {
		return fmt.Errorf("%s", err.String())
	}
	return nil
}

func setDiskMetadata(cfg config.CpiConfig, diskID string, metadata map[string]interface{}) *cpiError {
	return execCPI(cfg, "set_disk_metadata", diskID, metadata).Error
}

func resizeDisk(cfg config.CpiConfig, diskID string, newSizeMB int) *cpiError {
	return execCPI(cfg, "resize_disk", diskID, newSizeMB).Error
}

func calculateVMCloudProperties(cfg config.CpiConfig, vmResources map[string]interface{}) (map[string]interface{}, *cpiError) {
	env := execCPI(cfg, "calculate_vm_cloud_properties", vmResources)
	if env.Error != nil {
		return nil, env.Error
	}
	var props map[string]interface{}
	Expect(json.Unmarshal(env.Result, &props)).To(Succeed())
	return props, nil
}

// ---------------------------------------------------------------------------
// Shared cloud-property / env helpers
// ---------------------------------------------------------------------------

func dynamicNetwork() map[string]interface{} {
	return map[string]interface{}{
		"default": map[string]interface{}{
			"type": "dynamic",
			"cloud_properties": map[string]interface{}{
				"net_id": mustEnv("BOSH_OPENSTACK_NET_ID"),
			},
		},
	}
}

func manualNetwork() map[string]interface{} {
	return map[string]interface{}{
		"default": map[string]interface{}{
			"type": "manual",
			"ip":   mustEnv("BOSH_OPENSTACK_MANUAL_IP"),
			"cloud_properties": map[string]interface{}{
				"net_id": mustEnv("BOSH_OPENSTACK_NET_ID"),
			},
		},
	}
}

func defaultResourcePool() map[string]interface{} {
	props := map[string]interface{}{
		"instance_type": getEnv("BOSH_OPENSTACK_INSTANCE_TYPE", "m1.small"),
	}
	if az := getEnv("BOSH_OPENSTACK_AVAILABILITY_ZONE", ""); az != "" {
		props["availability_zone"] = az
	}
	return props
}

// ---------------------------------------------------------------------------
// env helpers
// ---------------------------------------------------------------------------

func mustEnv(key string) string {
	v, ok := os.LookupEnv(key)
	Expect(ok).To(BeTrue(), "required env var %s is not set", key)
	Expect(v).ToNot(BeEmpty(), "required env var %s is empty", key)
	return v
}

func getEnv(key, fallback string) string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		return v
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		n, err := strconv.Atoi(v)
		Expect(err).NotTo(HaveOccurred(), "env var %s must be an integer, got %q", key, v)
		return n
	}
	return fallback
}
