package apiv1

import (
	"encoding/json"
	"errors"
)

type cloudID struct {
	cid string
}

var _ json.Unmarshaler = &cloudID{}
var _ json.Marshaler = cloudID{}

func NewCloudID(cid string) cloudID {
	if cid == "" {
		panic("Internal incosistency: CID must not be empty")
	}
	return cloudID{cid}
}

func (c cloudID) AsString() string { return c.cid }

func (c *cloudID) UnmarshalJSON(data []byte) error {
	var str string

	err := json.Unmarshal(data, &str)
	if err != nil {
		return err
	}

	if str == "" {
		return errors.New("Expected CID to be non-empty")
	}

	*c = cloudID{str}

	return nil
}

func (c cloudID) MarshalJSON() ([]byte, error) {
	return json.Marshal(c.cid)
}
