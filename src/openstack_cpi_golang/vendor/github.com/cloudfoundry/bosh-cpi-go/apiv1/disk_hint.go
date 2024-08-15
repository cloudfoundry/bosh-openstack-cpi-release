package apiv1

import (
	"encoding/json"
)

type DiskHint struct {
	val interface{}
}

var _ json.Unmarshaler = &DiskHint{}
var _ json.Marshaler = DiskHint{}

func NewDiskHintFromString(val string) DiskHint {
	return DiskHint{val}
}

func NewDiskHintFromMap(val map[string]interface{}) DiskHint {
	return DiskHint{val}
}

func (i *DiskHint) UnmarshalJSON(data []byte) error {
	var val interface{}

	err := json.Unmarshal(data, &val)
	if err != nil {
		return err
	}

	*i = DiskHint{val}

	return nil
}

func (i DiskHint) MarshalJSON() ([]byte, error) {
	return json.Marshal(i.val)
}
