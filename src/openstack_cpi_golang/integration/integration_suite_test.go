package integration_test

import (
	"bytes"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	boshlog "github.com/cloudfoundry/bosh-utils/logger"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestIntegration(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Integration Suite")
}

var defaultConfig config.CpiConfig
var bootFromVolumeConfig config.CpiConfig //nolint:unused // To be used in subsequent PR.
var logger = utils.NewLogger(boshlog.NewWriterLogger(boshlog.LevelDebug, os.Stderr))
var Mux *http.ServeMux
var Server *httptest.Server
var originalStdin *os.File
var originalStdout *os.File
var outChannel chan string
var stdOutWriter *os.File

var _ = BeforeEach(func() {
	originalStdin = os.Stdin
	originalStdout = os.Stdout

	outChannel, stdOutWriter = setupReadableStdOut()
})

var _ = AfterEach(func() {
	os.Stdin = originalStdin
	os.Stdout = originalStdout
})

func getDefaultConfig(url string) config.CpiConfig {
	defaultConfig.Cloud.Properties.Openstack = config.OpenstackConfig{
		AuthURL:                 url,
		Username:                "admin",
		APIKey:                  "admin",
		DomainName:              "domain",
		Tenant:                  "tenant",
		Region:                  "region",
		DefaultKeyName:          "default_key_name",
		StemcellPubliclyVisible: true,
		StateTimeOut:            1,
	}

	defaultConfig.Cloud.Properties.RetryConfig = config.RetryConfigMap{
		"default": config.RetryConfig{
			MaxAttempts:   10,
			SleepDuration: 0,
		},
	}

	return defaultConfig
}

// nolint:unused // To be used in subsequent PR.
func getBootFromVolumeConfig(url string) config.CpiConfig {
	bootFromVolumeConfig.Cloud.Properties.Openstack = config.OpenstackConfig{
		AuthURL:                 url,
		Username:                "admin",
		APIKey:                  "admin",
		DomainName:              "domain",
		Tenant:                  "tenant",
		Region:                  "region",
		DefaultKeyName:          "default_key_name",
		StemcellPubliclyVisible: true,
		BootFromVolume:          true,
	}

	return bootFromVolumeConfig
}

func SetupHTTP() {
	Mux = http.NewServeMux()

	loggingMux := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		Mux.ServeHTTP(w, r)
		log.Printf("Received request: %s %s\n", r.Method, r.URL.String())
	})

	Server = httptest.NewServer(loggingMux)
}

func Endpoint() string {
	return Server.URL
}

func TeardownHTTP() {
	Server.Close()
}

func MockAuthentication() {
	Mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			fmt.Fprintf(w, `{
					"versions": {"values": [
						{"status": "stable","id": "v3.0","links": [{ "href": "%s", "rel": "self" }]},
						{"status": "stable","id": "v2.0","links": [{ "href": "%s", "rel": "self" }]}
					]}
				}`, Endpoint()+"/v3", Endpoint()+"/v2.0")
		}
	})

	Mux.HandleFunc("/v3/auth/tokens", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodPost:
			w.Header().Add("X-Subject-Token", "0123456789")
			w.WriteHeader(http.StatusCreated)

			fmt.Fprintf(w, `{
					"token": {
						"expires_at": "2013-02-02T18:30:59.000000Z",
						"catalog": [{
							"endpoints": [
								{"id": "1", "interface": "public", "region": "RegionOne", "url": "%s/v2.1"},
								{"id": "2", "interface": "admin", "region": "RegionOne", "url": "%s/v2.1"},
								{"id": "3", "interface": "internal", "region": "RegionOne", "url": "%s/v2.1"}
							],
							"type": "compute", 
							"name": "nova"
						},{
							"endpoints": [
								{"id": "1", "interface": "public", "region": "RegionOne", "url": "%s/"},
								{"id": "2", "interface": "admin", "region": "RegionOne", "url": "%s/"},
								{"id": "3", "interface": "internal", "region": "RegionOne", "url": "%s/"}
							],
							"type": "network", 
							"name": "neutron"
						},{
							"endpoints": [{"url": "%s/","interface": "public","region": "RegionOne"}],
							"type": "image",
							"name": "glance"
						},{
						   "endpoints": [
							 { "id": "1", "interface": "public",  "region": "RegionOne", "url": "%s/v2.0"},
							 { "id": "2", "interface": "admin",   "region": "RegionOne", "url": "%s/v2.0"},
							 { "id": "3", "interface": "internal","region": "RegionOne", "url": "%s/v2.0"}
						  ],
						  "type": "load-balancer",
						  "name": "octavia"
						},{
						   "endpoints": [
							 { "id": "1", "interface": "public",  "region": "RegionOne", "url": "%s/v3"},
							 { "id": "2", "interface": "admin",   "region": "RegionOne", "url": "%s/v3"},
							 { "id": "3", "interface": "internal","region": "RegionOne", "url": "%s/v3"}
						  ],
						  "type": "volumev3",
						  "name": "cinderv3"
						}]
					}
				}`, Endpoint(), Endpoint(), Endpoint(), Endpoint(), Endpoint(), Endpoint(), Endpoint(), Endpoint(), Endpoint(), Endpoint(), Endpoint(), Endpoint(), Endpoint())
		}
	})
}

func writeJsonParamToStdIn(json string) {
	reader, writer, _ := os.Pipe()
	os.Stdin = reader

	go func() {
		_, err := writer.WriteString(json)
		if err != nil {
			return
		}
		err = writer.Close()
		if err != nil {
			return
		}
	}()
}

func setupReadableStdOut() (chan string, *os.File) {
	reader, writer, _ := os.Pipe()
	os.Stdout = writer
	outChannel := make(chan string)
	// copy the output in a separate goroutine so reading from the pipe doesn't block indefinitely
	go func() {
		var buf bytes.Buffer
		_, err := io.Copy(&buf, reader)
		if err != nil {
			return
		}
		outChannel <- buf.String()
	}()

	return outChannel, writer
}
