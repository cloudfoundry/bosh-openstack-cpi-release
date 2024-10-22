// Code generated by counterfeiter. DO NOT EDIT.
package loadbalancerfakes

import (
	"sync"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/loadbalancer"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/properties"
	"github.com/gophercloud/gophercloud/openstack/loadbalancer/v2/pools"
)

type FakeLoadbalancerService struct {
	CreatePoolMemberStub        func(pools.Pool, string, properties.LoadbalancerPool, string, int) (*pools.Member, error)
	createPoolMemberMutex       sync.RWMutex
	createPoolMemberArgsForCall []struct {
		arg1 pools.Pool
		arg2 string
		arg3 properties.LoadbalancerPool
		arg4 string
		arg5 int
	}
	createPoolMemberReturns struct {
		result1 *pools.Member
		result2 error
	}
	createPoolMemberReturnsOnCall map[int]struct {
		result1 *pools.Member
		result2 error
	}
	DeletePoolMemberStub        func(string, string, int) error
	deletePoolMemberMutex       sync.RWMutex
	deletePoolMemberArgsForCall []struct {
		arg1 string
		arg2 string
		arg3 int
	}
	deletePoolMemberReturns struct {
		result1 error
	}
	deletePoolMemberReturnsOnCall map[int]struct {
		result1 error
	}
	GetPoolStub        func(string) (pools.Pool, error)
	getPoolMutex       sync.RWMutex
	getPoolArgsForCall []struct {
		arg1 string
	}
	getPoolReturns struct {
		result1 pools.Pool
		result2 error
	}
	getPoolReturnsOnCall map[int]struct {
		result1 pools.Pool
		result2 error
	}
	invocations      map[string][][]interface{}
	invocationsMutex sync.RWMutex
}

func (fake *FakeLoadbalancerService) CreatePoolMember(arg1 pools.Pool, arg2 string, arg3 properties.LoadbalancerPool, arg4 string, arg5 int) (*pools.Member, error) {
	fake.createPoolMemberMutex.Lock()
	ret, specificReturn := fake.createPoolMemberReturnsOnCall[len(fake.createPoolMemberArgsForCall)]
	fake.createPoolMemberArgsForCall = append(fake.createPoolMemberArgsForCall, struct {
		arg1 pools.Pool
		arg2 string
		arg3 properties.LoadbalancerPool
		arg4 string
		arg5 int
	}{arg1, arg2, arg3, arg4, arg5})
	stub := fake.CreatePoolMemberStub
	fakeReturns := fake.createPoolMemberReturns
	fake.recordInvocation("CreatePoolMember", []interface{}{arg1, arg2, arg3, arg4, arg5})
	fake.createPoolMemberMutex.Unlock()
	if stub != nil {
		return stub(arg1, arg2, arg3, arg4, arg5)
	}
	if specificReturn {
		return ret.result1, ret.result2
	}
	return fakeReturns.result1, fakeReturns.result2
}

func (fake *FakeLoadbalancerService) CreatePoolMemberCallCount() int {
	fake.createPoolMemberMutex.RLock()
	defer fake.createPoolMemberMutex.RUnlock()
	return len(fake.createPoolMemberArgsForCall)
}

func (fake *FakeLoadbalancerService) CreatePoolMemberCalls(stub func(pools.Pool, string, properties.LoadbalancerPool, string, int) (*pools.Member, error)) {
	fake.createPoolMemberMutex.Lock()
	defer fake.createPoolMemberMutex.Unlock()
	fake.CreatePoolMemberStub = stub
}

func (fake *FakeLoadbalancerService) CreatePoolMemberArgsForCall(i int) (pools.Pool, string, properties.LoadbalancerPool, string, int) {
	fake.createPoolMemberMutex.RLock()
	defer fake.createPoolMemberMutex.RUnlock()
	argsForCall := fake.createPoolMemberArgsForCall[i]
	return argsForCall.arg1, argsForCall.arg2, argsForCall.arg3, argsForCall.arg4, argsForCall.arg5
}

func (fake *FakeLoadbalancerService) CreatePoolMemberReturns(result1 *pools.Member, result2 error) {
	fake.createPoolMemberMutex.Lock()
	defer fake.createPoolMemberMutex.Unlock()
	fake.CreatePoolMemberStub = nil
	fake.createPoolMemberReturns = struct {
		result1 *pools.Member
		result2 error
	}{result1, result2}
}

func (fake *FakeLoadbalancerService) CreatePoolMemberReturnsOnCall(i int, result1 *pools.Member, result2 error) {
	fake.createPoolMemberMutex.Lock()
	defer fake.createPoolMemberMutex.Unlock()
	fake.CreatePoolMemberStub = nil
	if fake.createPoolMemberReturnsOnCall == nil {
		fake.createPoolMemberReturnsOnCall = make(map[int]struct {
			result1 *pools.Member
			result2 error
		})
	}
	fake.createPoolMemberReturnsOnCall[i] = struct {
		result1 *pools.Member
		result2 error
	}{result1, result2}
}

func (fake *FakeLoadbalancerService) DeletePoolMember(arg1 string, arg2 string, arg3 int) error {
	fake.deletePoolMemberMutex.Lock()
	ret, specificReturn := fake.deletePoolMemberReturnsOnCall[len(fake.deletePoolMemberArgsForCall)]
	fake.deletePoolMemberArgsForCall = append(fake.deletePoolMemberArgsForCall, struct {
		arg1 string
		arg2 string
		arg3 int
	}{arg1, arg2, arg3})
	stub := fake.DeletePoolMemberStub
	fakeReturns := fake.deletePoolMemberReturns
	fake.recordInvocation("DeletePoolMember", []interface{}{arg1, arg2, arg3})
	fake.deletePoolMemberMutex.Unlock()
	if stub != nil {
		return stub(arg1, arg2, arg3)
	}
	if specificReturn {
		return ret.result1
	}
	return fakeReturns.result1
}

func (fake *FakeLoadbalancerService) DeletePoolMemberCallCount() int {
	fake.deletePoolMemberMutex.RLock()
	defer fake.deletePoolMemberMutex.RUnlock()
	return len(fake.deletePoolMemberArgsForCall)
}

func (fake *FakeLoadbalancerService) DeletePoolMemberCalls(stub func(string, string, int) error) {
	fake.deletePoolMemberMutex.Lock()
	defer fake.deletePoolMemberMutex.Unlock()
	fake.DeletePoolMemberStub = stub
}

func (fake *FakeLoadbalancerService) DeletePoolMemberArgsForCall(i int) (string, string, int) {
	fake.deletePoolMemberMutex.RLock()
	defer fake.deletePoolMemberMutex.RUnlock()
	argsForCall := fake.deletePoolMemberArgsForCall[i]
	return argsForCall.arg1, argsForCall.arg2, argsForCall.arg3
}

func (fake *FakeLoadbalancerService) DeletePoolMemberReturns(result1 error) {
	fake.deletePoolMemberMutex.Lock()
	defer fake.deletePoolMemberMutex.Unlock()
	fake.DeletePoolMemberStub = nil
	fake.deletePoolMemberReturns = struct {
		result1 error
	}{result1}
}

func (fake *FakeLoadbalancerService) DeletePoolMemberReturnsOnCall(i int, result1 error) {
	fake.deletePoolMemberMutex.Lock()
	defer fake.deletePoolMemberMutex.Unlock()
	fake.DeletePoolMemberStub = nil
	if fake.deletePoolMemberReturnsOnCall == nil {
		fake.deletePoolMemberReturnsOnCall = make(map[int]struct {
			result1 error
		})
	}
	fake.deletePoolMemberReturnsOnCall[i] = struct {
		result1 error
	}{result1}
}

func (fake *FakeLoadbalancerService) GetPool(arg1 string) (pools.Pool, error) {
	fake.getPoolMutex.Lock()
	ret, specificReturn := fake.getPoolReturnsOnCall[len(fake.getPoolArgsForCall)]
	fake.getPoolArgsForCall = append(fake.getPoolArgsForCall, struct {
		arg1 string
	}{arg1})
	stub := fake.GetPoolStub
	fakeReturns := fake.getPoolReturns
	fake.recordInvocation("GetPool", []interface{}{arg1})
	fake.getPoolMutex.Unlock()
	if stub != nil {
		return stub(arg1)
	}
	if specificReturn {
		return ret.result1, ret.result2
	}
	return fakeReturns.result1, fakeReturns.result2
}

func (fake *FakeLoadbalancerService) GetPoolCallCount() int {
	fake.getPoolMutex.RLock()
	defer fake.getPoolMutex.RUnlock()
	return len(fake.getPoolArgsForCall)
}

func (fake *FakeLoadbalancerService) GetPoolCalls(stub func(string) (pools.Pool, error)) {
	fake.getPoolMutex.Lock()
	defer fake.getPoolMutex.Unlock()
	fake.GetPoolStub = stub
}

func (fake *FakeLoadbalancerService) GetPoolArgsForCall(i int) string {
	fake.getPoolMutex.RLock()
	defer fake.getPoolMutex.RUnlock()
	argsForCall := fake.getPoolArgsForCall[i]
	return argsForCall.arg1
}

func (fake *FakeLoadbalancerService) GetPoolReturns(result1 pools.Pool, result2 error) {
	fake.getPoolMutex.Lock()
	defer fake.getPoolMutex.Unlock()
	fake.GetPoolStub = nil
	fake.getPoolReturns = struct {
		result1 pools.Pool
		result2 error
	}{result1, result2}
}

func (fake *FakeLoadbalancerService) GetPoolReturnsOnCall(i int, result1 pools.Pool, result2 error) {
	fake.getPoolMutex.Lock()
	defer fake.getPoolMutex.Unlock()
	fake.GetPoolStub = nil
	if fake.getPoolReturnsOnCall == nil {
		fake.getPoolReturnsOnCall = make(map[int]struct {
			result1 pools.Pool
			result2 error
		})
	}
	fake.getPoolReturnsOnCall[i] = struct {
		result1 pools.Pool
		result2 error
	}{result1, result2}
}

func (fake *FakeLoadbalancerService) Invocations() map[string][][]interface{} {
	fake.invocationsMutex.RLock()
	defer fake.invocationsMutex.RUnlock()
	fake.createPoolMemberMutex.RLock()
	defer fake.createPoolMemberMutex.RUnlock()
	fake.deletePoolMemberMutex.RLock()
	defer fake.deletePoolMemberMutex.RUnlock()
	fake.getPoolMutex.RLock()
	defer fake.getPoolMutex.RUnlock()
	copiedInvocations := map[string][][]interface{}{}
	for key, value := range fake.invocations {
		copiedInvocations[key] = value
	}
	return copiedInvocations
}

func (fake *FakeLoadbalancerService) recordInvocation(key string, args []interface{}) {
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

var _ loadbalancer.LoadbalancerService = new(FakeLoadbalancerService)