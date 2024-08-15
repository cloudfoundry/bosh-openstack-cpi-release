package rpc

import (
	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
)

type ActionFactory interface {
	Create(method string, apiVersion int, context apiv1.CallContext) (interface{}, error)
}

type Dispatcher interface {
	// Dispatch interprets request bytes, executes request,
	// captures response and return response bytes.
	// It panics if built-in errors fail to serialize.
	Dispatch([]byte) []byte
}

type Caller interface {
	Call(interface{}, []interface{}) (interface{}, error)
}

type CloudError interface {
	Error() string
	Type() string
}

type RetryableError interface {
	Error() string
	CanRetry() bool
}
