package apiv1

import (
	"encoding/json"
)

type CloudPropsImpl struct {
	json.RawMessage
}

var _ json.Marshaler = CloudPropsImpl{}

func (c CloudPropsImpl) As(val interface{}) error {
	return json.Unmarshal([]byte(c.RawMessage), val)
}

func (c CloudPropsImpl) MarshalJSON() ([]byte, error) {
	return json.Marshal(c.RawMessage)
}

func (c CloudPropsImpl) _final() {}
