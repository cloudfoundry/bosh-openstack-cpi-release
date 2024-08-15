package apiv1

import (
	"encoding/json"
	"errors"
)

type VMCloudPropsImpl struct {
	val interface{}
}

var _ json.Marshaler = VMCloudPropsImpl{}

func NewVMCloudPropsFromMap(val map[string]interface{}) VMCloudPropsImpl {
	return VMCloudPropsImpl{val}
}

func (i VMCloudPropsImpl) MarshalJSON() ([]byte, error) {
	return json.Marshal(i.val)
}

func (i VMCloudPropsImpl) As(val interface{}) error {
	return errors.New("Expected to not convert VMCloudPropsImpl")
}

func (i VMCloudPropsImpl) _final() {}
