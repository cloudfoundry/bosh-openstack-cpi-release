package helpers

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// Runner is a thin wrapper around the bosh-go CLI binary.
type Runner struct {
	env []string
}

// NewRunner creates a Runner pre-loaded with director credentials from cfg.
func NewRunner(cfg *Config) *Runner {
	env := append(os.Environ(),
		"BOSH_ENVIRONMENT="+cfg.Director,
		"BOSH_CLIENT="+cfg.Client,
		"BOSH_CLIENT_SECRET="+cfg.ClientSecret,
		"BOSH_CA_CERT="+cfg.CACert,
	)
	if cfg.AllProxy != "" {
		env = append(env, "BOSH_ALL_PROXY="+cfg.AllProxy)
	}
	return &Runner{env: env}
}

// Run executes bosh-go with the given args, returning combined stdout+stderr.
func (r *Runner) Run(args ...string) (string, error) {
	cmd := exec.Command("bosh-go", append([]string{"-n"}, args...)...)
	cmd.Env = r.env
	out, err := cmd.CombinedOutput()
	if err != nil {
		return string(out), fmt.Errorf("bosh-go %s: %w\noutput: %s", strings.Join(args, " "), err, out)
	}
	return string(out), nil
}

// UploadStemcell uploads a stemcell tarball, skipping if already present.
func (r *Runner) UploadStemcell(path string) error {
	_, err := r.Run("upload-stemcell", path, "--fix")
	return err
}

// UpdateCloudConfig applies the given cloud config YAML file to the director.
func (r *Runner) UpdateCloudConfig(path string) error {
	_, err := r.Run("update-cloud-config", path)
	return err
}

// Deploy deploys using the manifest at path. Returns combined output.
func (r *Runner) Deploy(manifestPath string) (string, error) {
	return r.Run("deploy", "-d", deploymentName(manifestPath), manifestPath)
}

// DeleteDeployment deletes the named deployment.
func (r *Runner) DeleteDeployment(name string) error {
	_, err := r.Run("delete-deployment", "-d", name)
	return err
}

// Recreate triggers a full recreate of all instances in the named deployment.
func (r *Runner) Recreate(deployment string) error {
	_, err := r.Run("recreate", "-d", deployment)
	return err
}

// SSH runs cmd on instance slug (e.g. "group/0") inside deployment, returning stdout.
func (r *Runner) SSH(deployment, instanceSlug, cmd string) (string, error) {
	return r.Run("ssh", "-d", deployment, instanceSlug, "-c", cmd)
}

// Instance holds the relevant fields from `bosh instances --json`.
type Instance struct {
	Name  string `json:"instance"`
	State string `json:"process_state"`
	IPs   string `json:"ips"`
}

// Instances returns a list of instances in the named deployment.
func (r *Runner) Instances(deployment string) ([]Instance, error) {
	out, err := r.Run("instances", "-d", deployment, "--json")
	if err != nil {
		return nil, err
	}
	return parseInstancesJSON(out)
}

// DiskIDs returns the disk CIDs attached to instances of a deployment.
func (r *Runner) DiskIDs(deployment string) ([]string, error) {
	out, err := r.Run("disks", "--orphaned", "--json")
	if err != nil {
		return nil, err
	}
	return parseDiskIDsJSON(out, deployment)
}

type instancesResponse struct {
	Tables []struct {
		Rows []Instance `json:"Rows"`
	} `json:"Tables"`
}

func parseInstancesJSON(raw string) ([]Instance, error) {
	// Trim non-JSON prefix (bosh sometimes emits a "Using environment..." line)
	idx := strings.Index(raw, "{")
	if idx < 0 {
		return nil, fmt.Errorf("no JSON in bosh instances output: %s", raw)
	}
	var resp instancesResponse
	if err := json.Unmarshal([]byte(raw[idx:]), &resp); err != nil {
		return nil, fmt.Errorf("parsing instances JSON: %w\nraw: %s", err, raw)
	}
	if len(resp.Tables) == 0 {
		return nil, nil
	}
	return resp.Tables[0].Rows, nil
}

type disksResponse struct {
	Tables []struct {
		Rows []struct {
			DiskCID    string `json:"disk_cid"`
			Deployment string `json:"deployment"`
		} `json:"Rows"`
	} `json:"Tables"`
}

func parseDiskIDsJSON(raw, deployment string) ([]string, error) {
	idx := strings.Index(raw, "{")
	if idx < 0 {
		return nil, nil
	}
	var resp disksResponse
	if err := json.Unmarshal([]byte(raw[idx:]), &resp); err != nil {
		return nil, err
	}
	var ids []string
	for _, t := range resp.Tables {
		for _, row := range t.Rows {
			if row.Deployment == deployment {
				ids = append(ids, row.DiskCID)
			}
		}
	}
	return ids, nil
}

// deploymentName extracts the deployment name from a manifest file: expects a
// "name:" key on the first line that starts with it, falling back to the filename.
func deploymentName(manifestPath string) string {
	data, err := os.ReadFile(manifestPath)
	if err != nil {
		return manifestPath
	}
	for _, line := range strings.Split(string(data), "\n") {
		if strings.HasPrefix(line, "name:") {
			return strings.TrimSpace(strings.TrimPrefix(line, "name:"))
		}
	}
	return manifestPath
}
