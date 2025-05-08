package integration_test

import (
	"fmt"
	"net/http"
	"sync/atomic"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Create Stemcell", func() {
	var count int64

	BeforeEach(func() {
		SetupHTTP()

		MockAuthentication()
	})

	AfterEach(func() {
		TeardownHTTP()
	})

	It("create a heavy stemcell image", func() {
		Mux.HandleFunc("/v2/images", func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusCreated)

			fmt.Fprintf(w, //nolint:errcheck
				`{
				"status": "queued",
				"visibility": "private",
				"id": "b2173dd3-7ad6-4362-baa6-a68bce3565cb",
				"file": "/v2/images/b2173dd3-7ad6-4362-baa6-a68bce3565cb/file",
				"schema": "/v2/schemas/image"
			}`)
		})

		Mux.HandleFunc("/v2/images/b2173dd3-7ad6-4362-baa6-a68bce3565cb/file", func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusNoContent)
		})

		writeJsonParamToStdIn(`{
			"method":"create_stemcell",
			"arguments":[
				"./testdata/image",
				{
					"disk":5120,"disk_format":
					"vmdk","container_format":"bare",
					"architecture":"x86_64",
					"vmware_ostype":"ubuntu64Guest"
				}
			]
		}`)

		err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
		Expect(err).ShouldNot(HaveOccurred())

		stdOutWriter.Close() //nolint:errcheck
		Expect(<-outChannel).To(ContainSubstring(`"result":"b2173dd3-7ad6-4362-baa6-a68bce3565cb"`))
	})

	It("create a light stemcell image", func() {
		Mux.HandleFunc("/v2/images/b2173dd3-7ad6-4362-baa6-a68bce3565cb", func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)

			fmt.Fprintf(w, //nolint:errcheck
				`{
				"status": "active",
				"visibility": "private",
				"id": "b2173dd3-7ad6-4362-baa6-a68bce3565cb",
				"file": "/v2/images/b2173dd3-7ad6-4362-baa6-a68bce3565cb/file",
				"schema": "/v2/schemas/image"
			}`)
		})

		writeJsonParamToStdIn(`{
			"method":"create_stemcell",
			"arguments":[
				"./testdata/image",
				{
					"image_id":"b2173dd3-7ad6-4362-baa6-a68bce3565cb",
					"disk":5120,"disk_format":
					"vmdk","container_format":"bare",
					"architecture":"x86_64",
					"vmware_ostype":"ubuntu64Guest"
				}
			]
		}`)

		err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
		Expect(err).ShouldNot(HaveOccurred())

		stdOutWriter.Close() //nolint:errcheck
		Expect(<-outChannel).To(ContainSubstring(`"result":"b2173dd3-7ad6-4362-baa6-a68bce3565cb"`))
	})

	It("retries the light stemcell creation", func() {
		Mux.HandleFunc("/v2/images/b2173dd3-7ad6-4362-baa6-a68bce3565cb", func(w http.ResponseWriter, r *http.Request) {

			if atomic.LoadInt64(&count) == 0 {
				// fail on first request
				w.WriteHeader(http.StatusInternalServerError)
				fmt.Fprintf(w, `{}`) //nolint:errcheck

				atomic.AddInt64(&count, 1)
			} else {
				// succeed on second request
				w.WriteHeader(http.StatusOK)
				fmt.Fprintf(w, //nolint:errcheck
					`{
					"status": "active",
					"visibility": "private",
					"id": "b2173dd3-7ad6-4362-baa6-a68bce3565cb",
					"file": "/v2/images/b2173dd3-7ad6-4362-baa6-a68bce3565cb/file",
					"schema": "/v2/schemas/image"
				}`)
			}
		})

		writeJsonParamToStdIn(`{
			"method":"create_stemcell",
			"arguments":[
				"./testdata/image",
				{
					"image_id":"b2173dd3-7ad6-4362-baa6-a68bce3565cb",
					"disk":5120,"disk_format":
					"vmdk","container_format":"bare",
					"architecture":"x86_64",
					"vmware_ostype":"ubuntu64Guest"
				}
			]
		}`)

		cpiConfig := getDefaultConfig(Endpoint())
		cpiConfig.Cloud.Properties.RetryConfig = config.RetryConfigMap{
			"default": {
				MaxAttempts:   10,
				SleepDuration: 0,
			},
		}
		err := cpi.Execute(cpiConfig, logger)
		Expect(err).ShouldNot(HaveOccurred())

		stdOutWriter.Close() //nolint:errcheck
		Expect(<-outChannel).To(ContainSubstring(`"result":"b2173dd3-7ad6-4362-baa6-a68bce3565cb"`))
	})
})
