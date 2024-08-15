package mocks

type MockPage struct{}

func (m MockPage) NextPageURL() (string, error) {
	return "", nil
}
func (m MockPage) IsEmpty() (bool, error) {
	return false, nil
}
func (m MockPage) GetBody() interface{} {
	return nil
}
