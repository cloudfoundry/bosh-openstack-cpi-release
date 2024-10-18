// Code generated by counterfeiter. DO NOT EDIT.
package openstackfakes

import (
	"sync"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/openstack"
	"github.com/gophercloud/gophercloud"
)

type FakeOpenstackFacade struct {
	AuthenticatedClientStub        func(gophercloud.AuthOptions) (*gophercloud.ProviderClient, error)
	authenticatedClientMutex       sync.RWMutex
	authenticatedClientArgsForCall []struct {
		arg1 gophercloud.AuthOptions
	}
	authenticatedClientReturns struct {
		result1 *gophercloud.ProviderClient
		result2 error
	}
	authenticatedClientReturnsOnCall map[int]struct {
		result1 *gophercloud.ProviderClient
		result2 error
	}
	NewBlockStorageV3Stub        func(*gophercloud.ProviderClient, gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error)
	newBlockStorageV3Mutex       sync.RWMutex
	newBlockStorageV3ArgsForCall []struct {
		arg1 *gophercloud.ProviderClient
		arg2 gophercloud.EndpointOpts
	}
	newBlockStorageV3Returns struct {
		result1 *gophercloud.ServiceClient
		result2 error
	}
	newBlockStorageV3ReturnsOnCall map[int]struct {
		result1 *gophercloud.ServiceClient
		result2 error
	}
	NewComputeV2Stub        func(*gophercloud.ProviderClient, gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error)
	newComputeV2Mutex       sync.RWMutex
	newComputeV2ArgsForCall []struct {
		arg1 *gophercloud.ProviderClient
		arg2 gophercloud.EndpointOpts
	}
	newComputeV2Returns struct {
		result1 *gophercloud.ServiceClient
		result2 error
	}
	newComputeV2ReturnsOnCall map[int]struct {
		result1 *gophercloud.ServiceClient
		result2 error
	}
	NewImageServiceV2Stub        func(*gophercloud.ProviderClient, gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error)
	newImageServiceV2Mutex       sync.RWMutex
	newImageServiceV2ArgsForCall []struct {
		arg1 *gophercloud.ProviderClient
		arg2 gophercloud.EndpointOpts
	}
	newImageServiceV2Returns struct {
		result1 *gophercloud.ServiceClient
		result2 error
	}
	newImageServiceV2ReturnsOnCall map[int]struct {
		result1 *gophercloud.ServiceClient
		result2 error
	}
	NewLoadBalancerV2Stub        func(*gophercloud.ProviderClient, gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error)
	newLoadBalancerV2Mutex       sync.RWMutex
	newLoadBalancerV2ArgsForCall []struct {
		arg1 *gophercloud.ProviderClient
		arg2 gophercloud.EndpointOpts
	}
	newLoadBalancerV2Returns struct {
		result1 *gophercloud.ServiceClient
		result2 error
	}
	newLoadBalancerV2ReturnsOnCall map[int]struct {
		result1 *gophercloud.ServiceClient
		result2 error
	}
	NewNetworkV2Stub        func(*gophercloud.ProviderClient, gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error)
	newNetworkV2Mutex       sync.RWMutex
	newNetworkV2ArgsForCall []struct {
		arg1 *gophercloud.ProviderClient
		arg2 gophercloud.EndpointOpts
	}
	newNetworkV2Returns struct {
		result1 *gophercloud.ServiceClient
		result2 error
	}
	newNetworkV2ReturnsOnCall map[int]struct {
		result1 *gophercloud.ServiceClient
		result2 error
	}
	invocations      map[string][][]interface{}
	invocationsMutex sync.RWMutex
}

func (fake *FakeOpenstackFacade) AuthenticatedClient(arg1 gophercloud.AuthOptions) (*gophercloud.ProviderClient, error) {
	fake.authenticatedClientMutex.Lock()
	ret, specificReturn := fake.authenticatedClientReturnsOnCall[len(fake.authenticatedClientArgsForCall)]
	fake.authenticatedClientArgsForCall = append(fake.authenticatedClientArgsForCall, struct {
		arg1 gophercloud.AuthOptions
	}{arg1})
	stub := fake.AuthenticatedClientStub
	fakeReturns := fake.authenticatedClientReturns
	fake.recordInvocation("AuthenticatedClient", []interface{}{arg1})
	fake.authenticatedClientMutex.Unlock()
	if stub != nil {
		return stub(arg1)
	}
	if specificReturn {
		return ret.result1, ret.result2
	}
	return fakeReturns.result1, fakeReturns.result2
}

func (fake *FakeOpenstackFacade) AuthenticatedClientCallCount() int {
	fake.authenticatedClientMutex.RLock()
	defer fake.authenticatedClientMutex.RUnlock()
	return len(fake.authenticatedClientArgsForCall)
}

func (fake *FakeOpenstackFacade) AuthenticatedClientCalls(stub func(gophercloud.AuthOptions) (*gophercloud.ProviderClient, error)) {
	fake.authenticatedClientMutex.Lock()
	defer fake.authenticatedClientMutex.Unlock()
	fake.AuthenticatedClientStub = stub
}

func (fake *FakeOpenstackFacade) AuthenticatedClientArgsForCall(i int) gophercloud.AuthOptions {
	fake.authenticatedClientMutex.RLock()
	defer fake.authenticatedClientMutex.RUnlock()
	argsForCall := fake.authenticatedClientArgsForCall[i]
	return argsForCall.arg1
}

func (fake *FakeOpenstackFacade) AuthenticatedClientReturns(result1 *gophercloud.ProviderClient, result2 error) {
	fake.authenticatedClientMutex.Lock()
	defer fake.authenticatedClientMutex.Unlock()
	fake.AuthenticatedClientStub = nil
	fake.authenticatedClientReturns = struct {
		result1 *gophercloud.ProviderClient
		result2 error
	}{result1, result2}
}

func (fake *FakeOpenstackFacade) AuthenticatedClientReturnsOnCall(i int, result1 *gophercloud.ProviderClient, result2 error) {
	fake.authenticatedClientMutex.Lock()
	defer fake.authenticatedClientMutex.Unlock()
	fake.AuthenticatedClientStub = nil
	if fake.authenticatedClientReturnsOnCall == nil {
		fake.authenticatedClientReturnsOnCall = make(map[int]struct {
			result1 *gophercloud.ProviderClient
			result2 error
		})
	}
	fake.authenticatedClientReturnsOnCall[i] = struct {
		result1 *gophercloud.ProviderClient
		result2 error
	}{result1, result2}
}

func (fake *FakeOpenstackFacade) NewBlockStorageV3(arg1 *gophercloud.ProviderClient, arg2 gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error) {
	fake.newBlockStorageV3Mutex.Lock()
	ret, specificReturn := fake.newBlockStorageV3ReturnsOnCall[len(fake.newBlockStorageV3ArgsForCall)]
	fake.newBlockStorageV3ArgsForCall = append(fake.newBlockStorageV3ArgsForCall, struct {
		arg1 *gophercloud.ProviderClient
		arg2 gophercloud.EndpointOpts
	}{arg1, arg2})
	stub := fake.NewBlockStorageV3Stub
	fakeReturns := fake.newBlockStorageV3Returns
	fake.recordInvocation("NewBlockStorageV3", []interface{}{arg1, arg2})
	fake.newBlockStorageV3Mutex.Unlock()
	if stub != nil {
		return stub(arg1, arg2)
	}
	if specificReturn {
		return ret.result1, ret.result2
	}
	return fakeReturns.result1, fakeReturns.result2
}

func (fake *FakeOpenstackFacade) NewBlockStorageV3CallCount() int {
	fake.newBlockStorageV3Mutex.RLock()
	defer fake.newBlockStorageV3Mutex.RUnlock()
	return len(fake.newBlockStorageV3ArgsForCall)
}

func (fake *FakeOpenstackFacade) NewBlockStorageV3Calls(stub func(*gophercloud.ProviderClient, gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error)) {
	fake.newBlockStorageV3Mutex.Lock()
	defer fake.newBlockStorageV3Mutex.Unlock()
	fake.NewBlockStorageV3Stub = stub
}

func (fake *FakeOpenstackFacade) NewBlockStorageV3ArgsForCall(i int) (*gophercloud.ProviderClient, gophercloud.EndpointOpts) {
	fake.newBlockStorageV3Mutex.RLock()
	defer fake.newBlockStorageV3Mutex.RUnlock()
	argsForCall := fake.newBlockStorageV3ArgsForCall[i]
	return argsForCall.arg1, argsForCall.arg2
}

func (fake *FakeOpenstackFacade) NewBlockStorageV3Returns(result1 *gophercloud.ServiceClient, result2 error) {
	fake.newBlockStorageV3Mutex.Lock()
	defer fake.newBlockStorageV3Mutex.Unlock()
	fake.NewBlockStorageV3Stub = nil
	fake.newBlockStorageV3Returns = struct {
		result1 *gophercloud.ServiceClient
		result2 error
	}{result1, result2}
}

func (fake *FakeOpenstackFacade) NewBlockStorageV3ReturnsOnCall(i int, result1 *gophercloud.ServiceClient, result2 error) {
	fake.newBlockStorageV3Mutex.Lock()
	defer fake.newBlockStorageV3Mutex.Unlock()
	fake.NewBlockStorageV3Stub = nil
	if fake.newBlockStorageV3ReturnsOnCall == nil {
		fake.newBlockStorageV3ReturnsOnCall = make(map[int]struct {
			result1 *gophercloud.ServiceClient
			result2 error
		})
	}
	fake.newBlockStorageV3ReturnsOnCall[i] = struct {
		result1 *gophercloud.ServiceClient
		result2 error
	}{result1, result2}
}

func (fake *FakeOpenstackFacade) NewComputeV2(arg1 *gophercloud.ProviderClient, arg2 gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error) {
	fake.newComputeV2Mutex.Lock()
	ret, specificReturn := fake.newComputeV2ReturnsOnCall[len(fake.newComputeV2ArgsForCall)]
	fake.newComputeV2ArgsForCall = append(fake.newComputeV2ArgsForCall, struct {
		arg1 *gophercloud.ProviderClient
		arg2 gophercloud.EndpointOpts
	}{arg1, arg2})
	stub := fake.NewComputeV2Stub
	fakeReturns := fake.newComputeV2Returns
	fake.recordInvocation("NewComputeV2", []interface{}{arg1, arg2})
	fake.newComputeV2Mutex.Unlock()
	if stub != nil {
		return stub(arg1, arg2)
	}
	if specificReturn {
		return ret.result1, ret.result2
	}
	return fakeReturns.result1, fakeReturns.result2
}

func (fake *FakeOpenstackFacade) NewComputeV2CallCount() int {
	fake.newComputeV2Mutex.RLock()
	defer fake.newComputeV2Mutex.RUnlock()
	return len(fake.newComputeV2ArgsForCall)
}

func (fake *FakeOpenstackFacade) NewComputeV2Calls(stub func(*gophercloud.ProviderClient, gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error)) {
	fake.newComputeV2Mutex.Lock()
	defer fake.newComputeV2Mutex.Unlock()
	fake.NewComputeV2Stub = stub
}

func (fake *FakeOpenstackFacade) NewComputeV2ArgsForCall(i int) (*gophercloud.ProviderClient, gophercloud.EndpointOpts) {
	fake.newComputeV2Mutex.RLock()
	defer fake.newComputeV2Mutex.RUnlock()
	argsForCall := fake.newComputeV2ArgsForCall[i]
	return argsForCall.arg1, argsForCall.arg2
}

func (fake *FakeOpenstackFacade) NewComputeV2Returns(result1 *gophercloud.ServiceClient, result2 error) {
	fake.newComputeV2Mutex.Lock()
	defer fake.newComputeV2Mutex.Unlock()
	fake.NewComputeV2Stub = nil
	fake.newComputeV2Returns = struct {
		result1 *gophercloud.ServiceClient
		result2 error
	}{result1, result2}
}

func (fake *FakeOpenstackFacade) NewComputeV2ReturnsOnCall(i int, result1 *gophercloud.ServiceClient, result2 error) {
	fake.newComputeV2Mutex.Lock()
	defer fake.newComputeV2Mutex.Unlock()
	fake.NewComputeV2Stub = nil
	if fake.newComputeV2ReturnsOnCall == nil {
		fake.newComputeV2ReturnsOnCall = make(map[int]struct {
			result1 *gophercloud.ServiceClient
			result2 error
		})
	}
	fake.newComputeV2ReturnsOnCall[i] = struct {
		result1 *gophercloud.ServiceClient
		result2 error
	}{result1, result2}
}

func (fake *FakeOpenstackFacade) NewImageServiceV2(arg1 *gophercloud.ProviderClient, arg2 gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error) {
	fake.newImageServiceV2Mutex.Lock()
	ret, specificReturn := fake.newImageServiceV2ReturnsOnCall[len(fake.newImageServiceV2ArgsForCall)]
	fake.newImageServiceV2ArgsForCall = append(fake.newImageServiceV2ArgsForCall, struct {
		arg1 *gophercloud.ProviderClient
		arg2 gophercloud.EndpointOpts
	}{arg1, arg2})
	stub := fake.NewImageServiceV2Stub
	fakeReturns := fake.newImageServiceV2Returns
	fake.recordInvocation("NewImageServiceV2", []interface{}{arg1, arg2})
	fake.newImageServiceV2Mutex.Unlock()
	if stub != nil {
		return stub(arg1, arg2)
	}
	if specificReturn {
		return ret.result1, ret.result2
	}
	return fakeReturns.result1, fakeReturns.result2
}

func (fake *FakeOpenstackFacade) NewImageServiceV2CallCount() int {
	fake.newImageServiceV2Mutex.RLock()
	defer fake.newImageServiceV2Mutex.RUnlock()
	return len(fake.newImageServiceV2ArgsForCall)
}

func (fake *FakeOpenstackFacade) NewImageServiceV2Calls(stub func(*gophercloud.ProviderClient, gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error)) {
	fake.newImageServiceV2Mutex.Lock()
	defer fake.newImageServiceV2Mutex.Unlock()
	fake.NewImageServiceV2Stub = stub
}

func (fake *FakeOpenstackFacade) NewImageServiceV2ArgsForCall(i int) (*gophercloud.ProviderClient, gophercloud.EndpointOpts) {
	fake.newImageServiceV2Mutex.RLock()
	defer fake.newImageServiceV2Mutex.RUnlock()
	argsForCall := fake.newImageServiceV2ArgsForCall[i]
	return argsForCall.arg1, argsForCall.arg2
}

func (fake *FakeOpenstackFacade) NewImageServiceV2Returns(result1 *gophercloud.ServiceClient, result2 error) {
	fake.newImageServiceV2Mutex.Lock()
	defer fake.newImageServiceV2Mutex.Unlock()
	fake.NewImageServiceV2Stub = nil
	fake.newImageServiceV2Returns = struct {
		result1 *gophercloud.ServiceClient
		result2 error
	}{result1, result2}
}

func (fake *FakeOpenstackFacade) NewImageServiceV2ReturnsOnCall(i int, result1 *gophercloud.ServiceClient, result2 error) {
	fake.newImageServiceV2Mutex.Lock()
	defer fake.newImageServiceV2Mutex.Unlock()
	fake.NewImageServiceV2Stub = nil
	if fake.newImageServiceV2ReturnsOnCall == nil {
		fake.newImageServiceV2ReturnsOnCall = make(map[int]struct {
			result1 *gophercloud.ServiceClient
			result2 error
		})
	}
	fake.newImageServiceV2ReturnsOnCall[i] = struct {
		result1 *gophercloud.ServiceClient
		result2 error
	}{result1, result2}
}

func (fake *FakeOpenstackFacade) NewLoadBalancerV2(arg1 *gophercloud.ProviderClient, arg2 gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error) {
	fake.newLoadBalancerV2Mutex.Lock()
	ret, specificReturn := fake.newLoadBalancerV2ReturnsOnCall[len(fake.newLoadBalancerV2ArgsForCall)]
	fake.newLoadBalancerV2ArgsForCall = append(fake.newLoadBalancerV2ArgsForCall, struct {
		arg1 *gophercloud.ProviderClient
		arg2 gophercloud.EndpointOpts
	}{arg1, arg2})
	stub := fake.NewLoadBalancerV2Stub
	fakeReturns := fake.newLoadBalancerV2Returns
	fake.recordInvocation("NewLoadBalancerV2", []interface{}{arg1, arg2})
	fake.newLoadBalancerV2Mutex.Unlock()
	if stub != nil {
		return stub(arg1, arg2)
	}
	if specificReturn {
		return ret.result1, ret.result2
	}
	return fakeReturns.result1, fakeReturns.result2
}

func (fake *FakeOpenstackFacade) NewLoadBalancerV2CallCount() int {
	fake.newLoadBalancerV2Mutex.RLock()
	defer fake.newLoadBalancerV2Mutex.RUnlock()
	return len(fake.newLoadBalancerV2ArgsForCall)
}

func (fake *FakeOpenstackFacade) NewLoadBalancerV2Calls(stub func(*gophercloud.ProviderClient, gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error)) {
	fake.newLoadBalancerV2Mutex.Lock()
	defer fake.newLoadBalancerV2Mutex.Unlock()
	fake.NewLoadBalancerV2Stub = stub
}

func (fake *FakeOpenstackFacade) NewLoadBalancerV2ArgsForCall(i int) (*gophercloud.ProviderClient, gophercloud.EndpointOpts) {
	fake.newLoadBalancerV2Mutex.RLock()
	defer fake.newLoadBalancerV2Mutex.RUnlock()
	argsForCall := fake.newLoadBalancerV2ArgsForCall[i]
	return argsForCall.arg1, argsForCall.arg2
}

func (fake *FakeOpenstackFacade) NewLoadBalancerV2Returns(result1 *gophercloud.ServiceClient, result2 error) {
	fake.newLoadBalancerV2Mutex.Lock()
	defer fake.newLoadBalancerV2Mutex.Unlock()
	fake.NewLoadBalancerV2Stub = nil
	fake.newLoadBalancerV2Returns = struct {
		result1 *gophercloud.ServiceClient
		result2 error
	}{result1, result2}
}

func (fake *FakeOpenstackFacade) NewLoadBalancerV2ReturnsOnCall(i int, result1 *gophercloud.ServiceClient, result2 error) {
	fake.newLoadBalancerV2Mutex.Lock()
	defer fake.newLoadBalancerV2Mutex.Unlock()
	fake.NewLoadBalancerV2Stub = nil
	if fake.newLoadBalancerV2ReturnsOnCall == nil {
		fake.newLoadBalancerV2ReturnsOnCall = make(map[int]struct {
			result1 *gophercloud.ServiceClient
			result2 error
		})
	}
	fake.newLoadBalancerV2ReturnsOnCall[i] = struct {
		result1 *gophercloud.ServiceClient
		result2 error
	}{result1, result2}
}

func (fake *FakeOpenstackFacade) NewNetworkV2(arg1 *gophercloud.ProviderClient, arg2 gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error) {
	fake.newNetworkV2Mutex.Lock()
	ret, specificReturn := fake.newNetworkV2ReturnsOnCall[len(fake.newNetworkV2ArgsForCall)]
	fake.newNetworkV2ArgsForCall = append(fake.newNetworkV2ArgsForCall, struct {
		arg1 *gophercloud.ProviderClient
		arg2 gophercloud.EndpointOpts
	}{arg1, arg2})
	stub := fake.NewNetworkV2Stub
	fakeReturns := fake.newNetworkV2Returns
	fake.recordInvocation("NewNetworkV2", []interface{}{arg1, arg2})
	fake.newNetworkV2Mutex.Unlock()
	if stub != nil {
		return stub(arg1, arg2)
	}
	if specificReturn {
		return ret.result1, ret.result2
	}
	return fakeReturns.result1, fakeReturns.result2
}

func (fake *FakeOpenstackFacade) NewNetworkV2CallCount() int {
	fake.newNetworkV2Mutex.RLock()
	defer fake.newNetworkV2Mutex.RUnlock()
	return len(fake.newNetworkV2ArgsForCall)
}

func (fake *FakeOpenstackFacade) NewNetworkV2Calls(stub func(*gophercloud.ProviderClient, gophercloud.EndpointOpts) (*gophercloud.ServiceClient, error)) {
	fake.newNetworkV2Mutex.Lock()
	defer fake.newNetworkV2Mutex.Unlock()
	fake.NewNetworkV2Stub = stub
}

func (fake *FakeOpenstackFacade) NewNetworkV2ArgsForCall(i int) (*gophercloud.ProviderClient, gophercloud.EndpointOpts) {
	fake.newNetworkV2Mutex.RLock()
	defer fake.newNetworkV2Mutex.RUnlock()
	argsForCall := fake.newNetworkV2ArgsForCall[i]
	return argsForCall.arg1, argsForCall.arg2
}

func (fake *FakeOpenstackFacade) NewNetworkV2Returns(result1 *gophercloud.ServiceClient, result2 error) {
	fake.newNetworkV2Mutex.Lock()
	defer fake.newNetworkV2Mutex.Unlock()
	fake.NewNetworkV2Stub = nil
	fake.newNetworkV2Returns = struct {
		result1 *gophercloud.ServiceClient
		result2 error
	}{result1, result2}
}

func (fake *FakeOpenstackFacade) NewNetworkV2ReturnsOnCall(i int, result1 *gophercloud.ServiceClient, result2 error) {
	fake.newNetworkV2Mutex.Lock()
	defer fake.newNetworkV2Mutex.Unlock()
	fake.NewNetworkV2Stub = nil
	if fake.newNetworkV2ReturnsOnCall == nil {
		fake.newNetworkV2ReturnsOnCall = make(map[int]struct {
			result1 *gophercloud.ServiceClient
			result2 error
		})
	}
	fake.newNetworkV2ReturnsOnCall[i] = struct {
		result1 *gophercloud.ServiceClient
		result2 error
	}{result1, result2}
}

func (fake *FakeOpenstackFacade) Invocations() map[string][][]interface{} {
	fake.invocationsMutex.RLock()
	defer fake.invocationsMutex.RUnlock()
	fake.authenticatedClientMutex.RLock()
	defer fake.authenticatedClientMutex.RUnlock()
	fake.newBlockStorageV3Mutex.RLock()
	defer fake.newBlockStorageV3Mutex.RUnlock()
	fake.newComputeV2Mutex.RLock()
	defer fake.newComputeV2Mutex.RUnlock()
	fake.newImageServiceV2Mutex.RLock()
	defer fake.newImageServiceV2Mutex.RUnlock()
	fake.newLoadBalancerV2Mutex.RLock()
	defer fake.newLoadBalancerV2Mutex.RUnlock()
	fake.newNetworkV2Mutex.RLock()
	defer fake.newNetworkV2Mutex.RUnlock()
	copiedInvocations := map[string][][]interface{}{}
	for key, value := range fake.invocations {
		copiedInvocations[key] = value
	}
	return copiedInvocations
}

func (fake *FakeOpenstackFacade) recordInvocation(key string, args []interface{}) {
	fake.invocationsMutex.Lock()
	defer fake.invocationsMutex.Unlock()
	if fake.invocations == nil {
		fake.invocations = map[string][][]interface{}{}
	}
	if fake.invocations[key] == nil {
		fake.invocations[key] = [][]interface{}{}
	}
	fake.invocations[key] = append(fake.invocations[key], args)
}

var _ openstack.OpenstackFacade = new(FakeOpenstackFacade)
