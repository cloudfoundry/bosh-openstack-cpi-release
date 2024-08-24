package rpc

import (
	"encoding/json"
	"fmt"

	boshlog "github.com/cloudfoundry/bosh-utils/logger"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
)

type Request struct {
	Method     string               `json:"method"`
	Arguments  []interface{}        `json:"arguments"`
	Context    apiv1.CloudPropsImpl `json:"context"`
	APIVersion int                  `json:"api_version"`
}

type Response struct {
	Result interface{}    `json:"result"`
	Error  *ResponseError `json:"error"`
	Log    string         `json:"log"`
}

type ResponseError struct {
	Type     string `json:"type"`
	Message  string `json:"message"`
	CanRetry bool   `json:"ok_to_retry"`
}

type JSONDispatcher struct {
	actionFactory ActionFactory
	caller        Caller

	logTag string
	logger boshlog.Logger
}

func NewJSONDispatcher(actionFactory ActionFactory, caller Caller, logger boshlog.Logger) JSONDispatcher {
	return JSONDispatcher{
		actionFactory: actionFactory,
		caller:        caller,

		logTag: "rpc.JSONDispatcher",
		logger: logger,
	}
}

func (c JSONDispatcher) Dispatch(reqBytes []byte) []byte {
	var req Request

	c.logger.DebugWithDetails(c.logTag, "Request bytes", string(reqBytes))

	err := json.Unmarshal(reqBytes, &req)
	if err != nil {
		return c.cpiError("Must provide valid JSON payload")
	}

	c.logger.DebugWithDetails(c.logTag, "Deserialized request", req)

	if req.Method == "" {
		return c.cpiError("Must provide 'method' key")
	}

	if req.Arguments == nil {
		return c.cpiError("Must provide 'arguments' key")
	}

	action, err := c.actionFactory.Create(req.Method, req.APIVersion, req.Context)
	if err != nil {
		return c.notImplementedError(err)
	}

	result, err := c.caller.Call(action, req.Arguments)
	if err != nil {
		return c.cloudError(err)
	}

	resp := Response{
		Result: result,
	}

	c.logger.DebugWithDetails(c.logTag, "Deserialized response", resp)

	respBytes, err := json.Marshal(resp)
	if err != nil {
		return c.cpiError("Failed to serialize result")
	}

	c.logger.DebugWithDetails(c.logTag, "Response bytes", string(respBytes))

	return respBytes
}

func (c JSONDispatcher) cloudError(err error) []byte {
	respErr := Response{
		Error: &ResponseError{},
	}

	if typedErr, ok := err.(CloudError); ok {
		respErr.Error.Type = typedErr.Type()
	} else {
		respErr.Error.Type = "Bosh::Clouds::CloudError"
	}

	respErr.Error.Message = err.Error()

	if typedErr, ok := err.(RetryableError); ok {
		respErr.Error.CanRetry = typedErr.CanRetry()
	}

	respErrBytes, err := json.Marshal(respErr)
	if err != nil {
		panic(err)
	}

	c.logger.DebugWithDetails(c.logTag, "CloudError response bytes", string(respErrBytes))

	return respErrBytes
}

func (c JSONDispatcher) cpiError(message string) []byte {
	respErr := Response{
		Error: &ResponseError{
			Type:    "Bosh::Clouds::CpiError",
			Message: message,
		},
	}

	respErrBytes, err := json.Marshal(respErr)
	if err != nil {
		panic(err)
	}

	c.logger.DebugWithDetails(c.logTag, "CpiError response bytes", string(respErrBytes))

	return respErrBytes
}

func (c JSONDispatcher) notImplementedError(err error) []byte {
	respErr := Response{
		Error: &ResponseError{
			Type:    "Bosh::Clouds::NotImplemented",
			Message: fmt.Sprintf("Must call implemented method: %s", err),
		},
	}

	respErrBytes, err := json.Marshal(respErr)
	if err != nil {
		panic(err)
	}

	c.logger.DebugWithDetails(c.logTag, "NotImplementedError response bytes", string(respErrBytes))

	return respErrBytes
}
