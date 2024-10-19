package image

import (
	"io"
	"net/http"
)

//counterfeiter:generate . HttpClient
type HttpClient interface {
	Do(req *http.Request) (*http.Response, error)

	NewRequest(method, url string, body io.Reader) (*http.Request, error)
}

type httpClient struct {
}

func NewHttpClient() HttpClient {
	return httpClient{}
}

func (c httpClient) Do(req *http.Request) (*http.Response, error) {
	return http.DefaultClient.Do(req)
}

func (c httpClient) NewRequest(method, url string, body io.Reader) (*http.Request, error) {
	return http.NewRequest(method, url, body)
}
