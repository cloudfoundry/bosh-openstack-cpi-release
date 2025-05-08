package integration_test

import (
	"fmt"
	"net/http"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("SNAPSHOT DISK", func() {

	BeforeEach(func() {
		SetupHTTP()
		MockAuthentication()
	})

	AfterEach(func() {
		TeardownHTTP()
	})

	Context("Positive cases: ", func() {

		BeforeEach(func() {
			Mux.HandleFunc("/v3/volumes/volume-id", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodGet:
					w.WriteHeader(http.StatusOK)
					_, _ = fmt.Fprintf(w, //nolint:errcheck
						`{
					"volume": {
						"id": "volume-id",
						"name": "old-name",
						"status": "ACTIVE",
						"attachments": [{ 
							"device": "dev1/dev2/dev3",
							"server_id": "server-id",
							"volume_id": "volume-id"
						}]    
					}
				}`)
				}
			})

			Mux.HandleFunc("/v3/snapshots", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodPost:
					w.WriteHeader(http.StatusAccepted)
					_, _ = fmt.Fprintf(w, //nolint:errcheck
						`{
						"snapshot": {
							"id": "snapshot-id",
							"force": true,
							"name": "snapshot-name",
							"description": "deployment/job/1/dev3",
							"metadata": {
								"deployment":    "deployment",
								"job":           "job",
								"index":         "1",
								"test":          "test",
								"director_name": "director_name",
								"instance_id":   "instance_id"
							}
						}
					}`)
				}
			})

			Mux.HandleFunc("/v3/snapshots/snapshot-id", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodGet:
					w.WriteHeader(http.StatusOK)
					_, _ = fmt.Fprintf(w, //nolint:errcheck
						`{
					"snapshot": {
						"id": "snapshot-id",
						"name": "snapshot-name",
						"description": "deployment/job/1/dev3",
						"STATUS": "available",
						"metadata": {
							"deployment":    "deployment",
							"job":           "job",
							"index":         "1",
							"test":          "test",
							"director_name": "director_name",
							"instance_id":   "instance_id"
						}
					}
				}`)
				}
			})

			Mux.HandleFunc("/v3/snapshots/snapshot-id/metadata", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodPut:
					w.WriteHeader(http.StatusOK)
					_, _ = fmt.Fprintf(w, //nolint:errcheck
						`{
					"snapShotID": "snapshot-id",
					"metadata": {
						"deployment":     "deployment",
						"test":           "test",
						"instance_id":    "instance_id",
						"director":       "director_name",
						"instance_index": "1",
						"instance_name":  "job/instance_id"
					}
				}`)
				}
			})
		})

		It("creates a new snapshot successfully", func() {
			writeJsonParamToStdIn(`{
				"method":"snapshot_disk",
				"arguments": [
					"volume-id",
					{
					"deployment":    "deployment",
					"job":           "job",
					"index":         1,
					"test":          "test",
					"director_name": "director_name",
					"instance_id":   "instance_id"
					}
				]
			}`)
			config := getDefaultConfig(Endpoint())
			err := cpi.Execute(config, logger)
			Expect(err).ShouldNot(HaveOccurred())

			_ = stdOutWriter.Close() //nolint:errcheck
			Expect(<-outChannel).To(ContainSubstring(`"result":"snapshot-id","error":null`))
		})
	})

	Context("Failure in GetVolume: ", func() {

		BeforeEach(func() {

			Mux.HandleFunc("/v3/volumes/volume-id", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodGet:
					w.WriteHeader(http.StatusUnauthorized)
					_, _ = fmt.Fprintf(w, //nolint:errcheck
						`{
						"volume": {
							"id": "volume-id",
							"name": "old-name",
							"status": "ACTIVE",
							"attachments": [{ 
								"device": "dev1/dev2/dev3",
								"server_id": "server-id",
								"volume_id": "volume-id"
							}]    
						}
					}`)
				}
			})

		})

		It("returns error if get volume fails", func() {
			writeJsonParamToStdIn(`{
				"method":"snapshot_disk",
				"arguments": [
					"volume-id",
					{
					"deployment":    "deployment",
					"job":           "job",
					"index":         1,
					"test":          "test",
					"director_name": "director_name",
					"instance_id":   "instance_id"
					}
				]
			}`)
			config := getDefaultConfig(Endpoint())
			err := cpi.Execute(config, logger)
			Expect(err).ShouldNot(HaveOccurred())

			_ = stdOutWriter.Close() //nolint:errcheck
			Expect(<-outChannel).To(ContainSubstring(`"message":"snapShotDisk: Failed to get volume ID`))
		})

	})

	Context("Failure in CreateSnapshot: ", func() {

		BeforeEach(func() {

			Mux.HandleFunc("/v3/volumes/volume-id", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodGet:
					w.WriteHeader(http.StatusOK)
					_, _ = fmt.Fprintf(w, //nolint:errcheck
						`{
					"volume": {
						"id": "volume-id",
						"name": "old-name",
						"status": "ACTIVE",
						"attachments": [{ 
							"device": "dev1/dev2/dev3",
							"server_id": "server-id",
							"volume_id": "volume-id"
						}]    
					}
				}`)
				}
			})

			Mux.HandleFunc("/v3/snapshots", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodPost:
					w.WriteHeader(http.StatusBadRequest)
				}
			})

		})

		It("returns error if create snapshot fails", func() {
			writeJsonParamToStdIn(`{
				"method":"snapshot_disk",
				"arguments": [
					"volume-id",
					{
					"deployment":    "deployment",
					"job":           "job",
					"index":         1,
					"test":          "test",
					"director_name": "director_name",
					"instance_id":   "instance_id"
					}
				]
			}`)
			config := getDefaultConfig(Endpoint())
			err := cpi.Execute(config, logger)
			Expect(err).ShouldNot(HaveOccurred())

			_ = stdOutWriter.Close() //nolint:errcheck
			Expect(<-outChannel).To(ContainSubstring(`"message":"snapShotDisk: Failed to create snapshot snapshot-`))
		})

	})

	Context("Failure in WaitForSnapshotToBecomeStatus: ", func() {

		BeforeEach(func() {

			Mux.HandleFunc("/v3/volumes/volume-id", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodGet:
					w.WriteHeader(http.StatusOK)
					_, _ = fmt.Fprintf(w, //nolint:errcheck
						`{
						"volume": {
							"id": "volume-id",
							"name": "old-name",
							"status": "ACTIVE",
							"attachments": [{ 
								"device": "dev1/dev2/dev3",
								"server_id": "server-id",
								"volume_id": "volume-id"
							}]    
						}
					}`)
				}
			})

			Mux.HandleFunc("/v3/snapshots", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodPost:
					w.WriteHeader(http.StatusAccepted)
					_, _ = fmt.Fprintf(w, //nolint:errcheck
						`{
						"snapshot": {
							"id": "snapshot-id",
							"force": true,
							"name": "snapshot-name",
							"description": "deployment/job/1/dev3",
							"metadata": {
								"deployment":    "deployment",
								"job":           "job",
								"index":         "1",
								"test":          "test",
								"director_name": "director_name",
								"instance_id":   "instance_id"
							}
						}
					}`)
				}
			})

			Mux.HandleFunc("/v3/snapshots/snapshot-id", func(w http.ResponseWriter, r *http.Request) {
				switch r.Method {
				case http.MethodGet:
					w.WriteHeader(http.StatusUnauthorized)
				}
			})
		})

		It("returns error if wait for snapshot fails", func() {
			writeJsonParamToStdIn(`{
				"method":"snapshot_disk",
				"arguments": [
					"volume-id",
					{
					"deployment":    "deployment",
					"job":           "job",
					"index":         1,
					"test":          "test",
					"director_name": "director_name",
					"instance_id":   "instance_id"
					}
				]
			}`)
			config := getDefaultConfig(Endpoint())
			err := cpi.Execute(config, logger)
			Expect(err).ShouldNot(HaveOccurred())

			_ = stdOutWriter.Close() //nolint:errcheck
			Expect(<-outChannel).To(ContainSubstring(`"message":"snapShotDisk: Failed while waiting for creating snapshot snapshot-`))
		})

	})

})
