package integration_test

import (
	"fmt"
	"net/http"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("RESIZE DISK", func() {

	BeforeEach(func() {
		SetupHTTP()
		MockAuthentication()
	})

	AfterEach(func() {
		TeardownHTTP()
	})

	Context("Failure in GetVolume: ", func() {

		BeforeEach(func() {
			Mux.HandleFunc("/v3/volumes/disk-id", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodGet:
					w.WriteHeader(http.StatusNotFound)
				}
			})
		})

		It("returns error if getter volume fails ", func() {
			writeJsonParamToStdIn(`{
					"method":"resize_disk",
					"arguments": [
						"disk-id",
						5000
					],
					"api_version": 2
			}`)

			err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
			Expect(err).ShouldNot(HaveOccurred())

			stdOutWriter.Close() //nolint:errcheck
			Expect(<-outChannel).To(ContainSubstring(`cannot resize volume because volume with id`))

		})
	})

	Context("Failure in Switch Case: ", func() {

		BeforeEach(func() {
			Mux.HandleFunc("/v3/volumes/disk-id", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodGet:
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, //nolint:errcheck
						`{
					"volume": {
						"id": "disk-id",
						"size": 5,
						"attachments": [{"AttachmentID": "test-attachment-id"}]      				
					}
					}`)
				}
			})
		})

		It("returns nil if current volumesize = new volumesize", func() {
			writeJsonParamToStdIn(`{
					"method":"resize_disk",
					"arguments": [
						"disk-id",
						5000
					],
					"api_version": 2
			}`)

			err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
			Expect(err).ShouldNot(HaveOccurred())

			stdOutWriter.Close() //nolint:errcheck
			Expect(<-outChannel).To(ContainSubstring(`{"result":null,"error":null,"log":""}`))
		})

		It("returns error if current volumesize > new volumesize ", func() {
			writeJsonParamToStdIn(`{
					"method":"resize_disk",
					"arguments": [
						"disk-id",
						4000
					],
					"api_version": 2
			}`)

			err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
			Expect(err).ShouldNot(HaveOccurred())

			stdOutWriter.Close() //nolint:errcheck
			Expect(<-outChannel).To(ContainSubstring(`cannot resize volume to a smaller size from`))
		})

		It("returns error if volumeattachments != nil", func() {
			writeJsonParamToStdIn(`{
					"method":"resize_disk",
					"arguments": [
						"disk-id",
						6000
					],
					"api_version": 2
			}`)

			err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
			Expect(err).ShouldNot(HaveOccurred())

			stdOutWriter.Close() //nolint:errcheck
			Expect(<-outChannel).To(ContainSubstring(`cannot resize volume disk-id due to attachments`))
		})
	})

	Context("Failure in ExtendVolumeSize: ", func() {

		BeforeEach(func() {
			Mux.HandleFunc("/v3/volumes/disk-id", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodGet:
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, //nolint:errcheck
						`{
					"volume": {
						"id": "disk-id",
						"size": 4,
						"attachments": null
					}
				}`)
				}
			})

			Mux.HandleFunc("/v3/volumes/disk-id/action", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodPost:
					w.WriteHeader(http.StatusNotFound)
				}
			})
		})

		It("returns error if volumeattachments != nil", func() {
			writeJsonParamToStdIn(`{
					"method":"resize_disk",
					"arguments": [
						"disk-id",
						5000
					],
					"api_version": 2
			}`)

			err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
			Expect(err).ShouldNot(HaveOccurred())

			stdOutWriter.Close() //nolint:errcheck
			Expect(<-outChannel).To(ContainSubstring(`failed to resize volume`))
		})
	})

	Context("Failure in WaitForVolumeToBecomeStatus: ", func() {

		BeforeEach(func() {
			Mux.HandleFunc("/v3/volumes/disk-id", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodGet:
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, //nolint:errcheck
						`{
					"volume": {
						"id": "disk-id",
						"size": 4,		
						"status": "error",
						"attachments": null
					}
				}`)
				}
			})

			Mux.HandleFunc("/v3/volumes/disk-id/action", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodPost:
					w.WriteHeader(http.StatusAccepted)
				}
			})
		})

		It("returns error while waiting for resizing", func() {
			writeJsonParamToStdIn(`{
					"method":"resize_disk",
					"arguments": [
						"disk-id",
						5000
					],
					"api_version": 2
			}`)

			config := getDefaultConfig(Endpoint())
			config.Cloud.Properties.Openstack.StateTimeOut = 0

			err := cpi.Execute(config, logger)
			Expect(err).ShouldNot(HaveOccurred())

			stdOutWriter.Close() //nolint:errcheck
			Expect(<-outChannel).To(ContainSubstring(`failed while waiting on resizing volume`))
		})
	})

	Context("Positive Case: ", func() {

		BeforeEach(func() {
			Mux.HandleFunc("/v3/volumes/disk-id", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodGet:
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, //nolint:errcheck
						`{
					"volume": {
						"id": "disk-id",
						"size": 4,
						"status": "available",
						"attachments": null
					}
				}`)
				}
			})

			Mux.HandleFunc("/v3/volumes/disk-id/action", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodPost:
					w.WriteHeader(http.StatusAccepted)
				}
			})
		})

		It("returns nil for successful run", func() {
			writeJsonParamToStdIn(`{
					"method":"resize_disk",
					"arguments": [
						"disk-id",
						5000
					],
					"api_version": 2
			}`)

			config := getDefaultConfig(Endpoint())
			config.Cloud.Properties.Openstack.StateTimeOut = 0

			err := cpi.Execute(config, logger)
			Expect(err).ShouldNot(HaveOccurred())

			stdOutWriter.Close() //nolint:errcheck
			Expect(<-outChannel).To(ContainSubstring(`{"result":null,"error":null,"log":""}`))
		})
	})

})
