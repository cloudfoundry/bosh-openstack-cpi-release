package utils_test

import (
	"errors"
	"net"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/config"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils/utilsfakes"
	"github.com/gophercloud/gophercloud"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

type MockNetError struct {
	timeout bool
	text    string
}

func (m MockNetError) Error() string   { return m.text }
func (m MockNetError) Timeout() bool   { return m.timeout }
func (m MockNetError) Temporary() bool { return !m.timeout }

var _ = Describe("RetryOnError", func() {
	var logger utilsfakes.FakeLogger
	var retryConfig config.RetryConfig

	BeforeEach(func() {
		retryConfig = config.RetryConfig{MaxAttempts: 10, SleepDuration: 0}
		logger = utilsfakes.FakeLogger{}
	})

	It("returns an error if max retries is reached", func() {
		err := utils.RetryOnError(retryConfig, &logger)(nil, "", "", nil, errors.New("boom"), 10)
		Expect(err.Error()).To(Equal("max retry attempts (10) reached, err: boom"))
	})

	It("logs the current error", func() {
		_ = utils.RetryOnError(retryConfig, &logger)(nil, "", "", nil, errors.New("boom"), 0)

		tag, msg, _ := logger.WarnArgsForCall(0)
		Expect(tag).To(Equal("retry on error"))
		Expect(msg).To(Equal("attempt failed with error: boom"))
	})

	It("raises received errors that should not be retried", func() {
		err := utils.RetryOnError(retryConfig, &logger)(nil, "", "", nil, errors.New("boom"), 0)

		Expect(err.Error()).To(Equal("boom"))
	})

	It("retries on HTTP 500 error", func() {
		testError := gophercloud.ErrUnexpectedResponseCode{
			Actual: 500,
		}

		err := utils.RetryOnError(retryConfig, &logger)(nil, "", "", nil, testError, 0)
		Expect(err).To(BeNil())

		tag, msg, _ := logger.WarnArgsForCall(1)
		Expect(tag).To(Equal("retry on error"))
		Expect(msg).To(Equal("detected HTTP error 500, sleeping for 0 seconds"))
	})

	It("retries on HTTP 503 error", func() {
		testError := gophercloud.ErrUnexpectedResponseCode{
			Actual: 503,
		}

		err := utils.RetryOnError(retryConfig, &logger)(nil, "", "", nil, testError, 0)
		Expect(err).To(BeNil())

		tag, msg, _ := logger.WarnArgsForCall(1)
		Expect(tag).To(Equal("retry on error"))
		Expect(msg).To(Equal("detected HTTP error 503, sleeping for 0 seconds"))
	})

	It("retries on Network timeouts", func() {
		netError := MockNetError{
			timeout: true,
			text:    "boom",
		}

		err := utils.RetryOnError(retryConfig, &logger)(nil, "", "", nil, &netError, 0)
		Expect(err).To(BeNil())

		tag, msg, _ := logger.WarnArgsForCall(1)
		Expect(tag).To(Equal("retry on error"))
		Expect(msg).To(Equal("detected timeout, sleeping for 0 seconds"))
	})

	It("retries on generic network errors", func() {
		opError := net.OpError{
			Op: "boom",
		}
		err := utils.RetryOnError(retryConfig, &logger)(nil, "", "", nil, &opError, 0)
		Expect(err).To(BeNil())

		tag, msg, _ := logger.WarnArgsForCall(1)
		Expect(tag).To(Equal("retry on error"))
		Expect(msg).To(Equal("detected network error, sleeping for 0 seconds"))
	})
})
