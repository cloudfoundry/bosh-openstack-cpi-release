package integration_test

import (
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("SetDiskMetadataMethod Integration Tests", func() {

	setMetadataIsSuccessful := true

	BeforeEach(func() {
		SetupHTTP()
		MockAuthentication()
		Mux.HandleFunc("/v3/volumes/volume-id-ok", func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet:
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusOK)
				metadata := map[string]string{
					"key1": "value1",
				}
				responsePayload := map[string]interface{}{
					"id":       "volume-id-ok",
					"metadata": metadata,
				}
				response, _ := json.Marshal(responsePayload)
				fmt.Fprint(w, string(response))
			case http.MethodPut:
				if setMetadataIsSuccessful {
					w.WriteHeader(http.StatusOK)
					responsePayload := map[string]interface{}{
						"id": "volume-id-ok",
						"metadata": map[string]interface{}{
							"key2": "value2",
						},
					}
					response, _ := json.Marshal(responsePayload)
					fmt.Fprint(w, string(response))
				} else {
					w.WriteHeader(http.StatusNotFound)
				}
			default:
				w.WriteHeader(http.StatusNotImplemented)
			}
		})
	})

	AfterEach(func() {
		TeardownHTTP()
	})

	Context("success case: SetDiskMetadata", func() {

		It("sets disk metadata", func() {
			setMetadataIsSuccessful = true
			writeJsonParamToStdIn(`{
				"method":"set_disk_metadata",
				"arguments": [
					"volume-id-ok",
					{
						"key2": "value2"
					}
				],
				"context": {},
				"api_version": 2
			}`)
			err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
			Expect(err).ShouldNot(HaveOccurred())
			stdOutWriter.Close()
			actual := <-outChannel
			fmt.Printf("actual: %s\n", actual)
			var response map[string]interface{}
			err = json.Unmarshal([]byte(actual), &response)
			Expect(err).ShouldNot(HaveOccurred())
			Expect(response).To(HaveKey("result"))
			Expect(response["result"]).To(BeNil())
			Expect(response).To(HaveKey("error"))
			Expect(response["error"]).To(BeNil())
		})
	})

	Context("fail case: SetDiskMetadata", func() {

		It("fails to set disk metadata", func() {
			setMetadataIsSuccessful = false
			writeJsonParamToStdIn(`{
				"method":"set_disk_metadata",
				"arguments": [
					"volume-id-ok",
					{
						"key2": "value2"
					}
				],
				"context": {},
				"api_version": 2
			}`)
			err := cpi.Execute(getDefaultConfig(Endpoint()), logger)
			Expect(err).ShouldNot(HaveOccurred())
			stdOutWriter.Close()
			actual := <-outChannel
			fmt.Printf("actual: %s\n", actual)
			var response map[string]interface{}
			err = json.Unmarshal([]byte(actual), &response)
			Expect(err).ShouldNot(HaveOccurred())
			Expect(response).To(HaveKey("result"))
			Expect(response["result"]).To(BeNil())
			Expect(response).To(HaveKey("error"))
			Expect(response["error"]).NotTo(BeNil())
		})
	})
})
