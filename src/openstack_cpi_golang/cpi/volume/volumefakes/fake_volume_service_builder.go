// Code generated by counterfeiter. DO NOT EDIT.
package volumefakes

import (
	"sync"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/volume"
)

type FakeVolumeServiceBuilder struct {
	BuildStub        func() (volume.VolumeService, error)
	buildMutex       sync.RWMutex
	buildArgsForCall []struct {
	}
	buildReturns struct {
		result1 volume.VolumeService
		result2 error
	}
	buildReturnsOnCall map[int]struct {
		result1 volume.VolumeService
		result2 error
	}
	invocations      map[string][][]interface{}
	invocationsMutex sync.RWMutex
}

func (fake *FakeVolumeServiceBuilder) Build() (volume.VolumeService, error) {
	fake.buildMutex.Lock()
	ret, specificReturn := fake.buildReturnsOnCall[len(fake.buildArgsForCall)]
	fake.buildArgsForCall = append(fake.buildArgsForCall, struct {
	}{})
	stub := fake.BuildStub
	fakeReturns := fake.buildReturns
	fake.recordInvocation("Build", []interface{}{})
	fake.buildMutex.Unlock()
	if stub != nil {
		return stub()
	}
	if specificReturn {
		return ret.result1, ret.result2
	}
	return fakeReturns.result1, fakeReturns.result2
}

func (fake *FakeVolumeServiceBuilder) BuildCallCount() int {
	fake.buildMutex.RLock()
	defer fake.buildMutex.RUnlock()
	return len(fake.buildArgsForCall)
}

func (fake *FakeVolumeServiceBuilder) BuildCalls(stub func() (volume.VolumeService, error)) {
	fake.buildMutex.Lock()
	defer fake.buildMutex.Unlock()
	fake.BuildStub = stub
}

func (fake *FakeVolumeServiceBuilder) BuildReturns(result1 volume.VolumeService, result2 error) {
	fake.buildMutex.Lock()
	defer fake.buildMutex.Unlock()
	fake.BuildStub = nil
	fake.buildReturns = struct {
		result1 volume.VolumeService
		result2 error
	}{result1, result2}
}

func (fake *FakeVolumeServiceBuilder) BuildReturnsOnCall(i int, result1 volume.VolumeService, result2 error) {
	fake.buildMutex.Lock()
	defer fake.buildMutex.Unlock()
	fake.BuildStub = nil
	if fake.buildReturnsOnCall == nil {
		fake.buildReturnsOnCall = make(map[int]struct {
			result1 volume.VolumeService
			result2 error
		})
	}
	fake.buildReturnsOnCall[i] = struct {
		result1 volume.VolumeService
		result2 error
	}{result1, result2}
}

func (fake *FakeVolumeServiceBuilder) Invocations() map[string][][]interface{} {
	fake.invocationsMutex.RLock()
	defer fake.invocationsMutex.RUnlock()
	fake.buildMutex.RLock()
	defer fake.buildMutex.RUnlock()
	copiedInvocations := map[string][][]interface{}{}
	for key, value := range fake.invocations {
		copiedInvocations[key] = value
	}
	return copiedInvocations
}

func (fake *FakeVolumeServiceBuilder) recordInvocation(key string, args []interface{}) {
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

var _ volume.VolumeServiceBuilder = new(FakeVolumeServiceBuilder)