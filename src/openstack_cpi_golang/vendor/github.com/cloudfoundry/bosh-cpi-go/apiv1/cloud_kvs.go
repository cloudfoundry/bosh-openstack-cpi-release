package apiv1

import (
	"encoding/json"
)

type cloudKVs struct {
	val map[string]interface{}
}

var _ json.Unmarshaler = &cloudKVs{}
var _ json.Marshaler = cloudKVs{}

func NewCloudKVs(val map[string]interface{}) cloudKVs {
	return cloudKVs{val}
}

func (c *cloudKVs) UnmarshalJSON(data []byte) error {
	var val map[string]interface{}

	err := json.Unmarshal(data, &val)
	if err != nil {
		return err
	}

	*c = cloudKVs{val}

	return nil
}

func (c cloudKVs) MarshalJSON() ([]byte, error) {
	return json.Marshal(c.val)
}
