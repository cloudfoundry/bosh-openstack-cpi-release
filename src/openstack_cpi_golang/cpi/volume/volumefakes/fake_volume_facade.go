// Code generated by counterfeiter. DO NOT EDIT.
package volumefakes

import (
	"sync"

	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/utils"
	"github.com/cloudfoundry/bosh-openstack-cpi-release/src/openstack_cpi_golang/cpi/volume"
	"github.com/gophercloud/gophercloud"
	"github.com/gophercloud/gophercloud/openstack/blockstorage/extensions/volumeactions"
	"github.com/gophercloud/gophercloud/openstack/blockstorage/v3/snapshots"
	"github.com/gophercloud/gophercloud/openstack/blockstorage/v3/volumes"
)

type FakeVolumeFacade struct {
	CreateSnapshotStub        func(*gophercloud.ServiceClient, snapshots.CreateOptsBuilder) (*snapshots.Snapshot, error)
	createSnapshotMutex       sync.RWMutex
	createSnapshotArgsForCall []struct {
		arg1 *gophercloud.ServiceClient
		arg2 snapshots.CreateOptsBuilder
	}
	createSnapshotReturns struct {
		result1 *snapshots.Snapshot
		result2 error
	}
	createSnapshotReturnsOnCall map[int]struct {
		result1 *snapshots.Snapshot
		result2 error
	}
	CreateVolumeStub        func(utils.ServiceClient, volumes.CreateOptsBuilder) (*volumes.Volume, error)
	createVolumeMutex       sync.RWMutex
	createVolumeArgsForCall []struct {
		arg1 utils.ServiceClient
		arg2 volumes.CreateOptsBuilder
	}
	createVolumeReturns struct {
		result1 *volumes.Volume
		result2 error
	}
	createVolumeReturnsOnCall map[int]struct {
		result1 *volumes.Volume
		result2 error
	}
	DeleteSnapshotStub        func(*gophercloud.ServiceClient, string) error
	deleteSnapshotMutex       sync.RWMutex
	deleteSnapshotArgsForCall []struct {
		arg1 *gophercloud.ServiceClient
		arg2 string
	}
	deleteSnapshotReturns struct {
		result1 error
	}
	deleteSnapshotReturnsOnCall map[int]struct {
		result1 error
	}
	DeleteVolumeStub        func(utils.RetryableServiceClient, string, volumes.DeleteOptsBuilder) error
	deleteVolumeMutex       sync.RWMutex
	deleteVolumeArgsForCall []struct {
		arg1 utils.RetryableServiceClient
		arg2 string
		arg3 volumes.DeleteOptsBuilder
	}
	deleteVolumeReturns struct {
		result1 error
	}
	deleteVolumeReturnsOnCall map[int]struct {
		result1 error
	}
	ExtendVolumeSizeStub        func(utils.ServiceClient, string, volumeactions.ExtendSizeOptsBuilder) error
	extendVolumeSizeMutex       sync.RWMutex
	extendVolumeSizeArgsForCall []struct {
		arg1 utils.ServiceClient
		arg2 string
		arg3 volumeactions.ExtendSizeOptsBuilder
	}
	extendVolumeSizeReturns struct {
		result1 error
	}
	extendVolumeSizeReturnsOnCall map[int]struct {
		result1 error
	}
	GetSnapshotStub        func(utils.RetryableServiceClient, string) (*snapshots.Snapshot, error)
	getSnapshotMutex       sync.RWMutex
	getSnapshotArgsForCall []struct {
		arg1 utils.RetryableServiceClient
		arg2 string
	}
	getSnapshotReturns struct {
		result1 *snapshots.Snapshot
		result2 error
	}
	getSnapshotReturnsOnCall map[int]struct {
		result1 *snapshots.Snapshot
		result2 error
	}
	GetVolumeStub        func(utils.RetryableServiceClient, string) (*volumes.Volume, error)
	getVolumeMutex       sync.RWMutex
	getVolumeArgsForCall []struct {
		arg1 utils.RetryableServiceClient
		arg2 string
	}
	getVolumeReturns struct {
		result1 *volumes.Volume
		result2 error
	}
	getVolumeReturnsOnCall map[int]struct {
		result1 *volumes.Volume
		result2 error
	}
	SetDiskMetadataStub        func(utils.ServiceClient, string, volumes.UpdateOptsBuilder) error
	setDiskMetadataMutex       sync.RWMutex
	setDiskMetadataArgsForCall []struct {
		arg1 utils.ServiceClient
		arg2 string
		arg3 volumes.UpdateOptsBuilder
	}
	setDiskMetadataReturns struct {
		result1 error
	}
	setDiskMetadataReturnsOnCall map[int]struct {
		result1 error
	}
	UpdateMetaDataSnapShotStub        func(*gophercloud.ServiceClient, string, snapshots.UpdateMetadataOptsBuilder) (map[string]interface{}, error)
	updateMetaDataSnapShotMutex       sync.RWMutex
	updateMetaDataSnapShotArgsForCall []struct {
		arg1 *gophercloud.ServiceClient
		arg2 string
		arg3 snapshots.UpdateMetadataOptsBuilder
	}
	updateMetaDataSnapShotReturns struct {
		result1 map[string]interface{}
		result2 error
	}
	updateMetaDataSnapShotReturnsOnCall map[int]struct {
		result1 map[string]interface{}
		result2 error
	}
	invocations      map[string][][]interface{}
	invocationsMutex sync.RWMutex
}

func (fake *FakeVolumeFacade) CreateSnapshot(arg1 *gophercloud.ServiceClient, arg2 snapshots.CreateOptsBuilder) (*snapshots.Snapshot, error) {
	fake.createSnapshotMutex.Lock()
	ret, specificReturn := fake.createSnapshotReturnsOnCall[len(fake.createSnapshotArgsForCall)]
	fake.createSnapshotArgsForCall = append(fake.createSnapshotArgsForCall, struct {
		arg1 *gophercloud.ServiceClient
		arg2 snapshots.CreateOptsBuilder
	}{arg1, arg2})
	stub := fake.CreateSnapshotStub
	fakeReturns := fake.createSnapshotReturns
	fake.recordInvocation("CreateSnapshot", []interface{}{arg1, arg2})
	fake.createSnapshotMutex.Unlock()
	if stub != nil {
		return stub(arg1, arg2)
	}
	if specificReturn {
		return ret.result1, ret.result2
	}
	return fakeReturns.result1, fakeReturns.result2
}

func (fake *FakeVolumeFacade) CreateSnapshotCallCount() int {
	fake.createSnapshotMutex.RLock()
	defer fake.createSnapshotMutex.RUnlock()
	return len(fake.createSnapshotArgsForCall)
}

func (fake *FakeVolumeFacade) CreateSnapshotCalls(stub func(*gophercloud.ServiceClient, snapshots.CreateOptsBuilder) (*snapshots.Snapshot, error)) {
	fake.createSnapshotMutex.Lock()
	defer fake.createSnapshotMutex.Unlock()
	fake.CreateSnapshotStub = stub
}

func (fake *FakeVolumeFacade) CreateSnapshotArgsForCall(i int) (*gophercloud.ServiceClient, snapshots.CreateOptsBuilder) {
	fake.createSnapshotMutex.RLock()
	defer fake.createSnapshotMutex.RUnlock()
	argsForCall := fake.createSnapshotArgsForCall[i]
	return argsForCall.arg1, argsForCall.arg2
}

func (fake *FakeVolumeFacade) CreateSnapshotReturns(result1 *snapshots.Snapshot, result2 error) {
	fake.createSnapshotMutex.Lock()
	defer fake.createSnapshotMutex.Unlock()
	fake.CreateSnapshotStub = nil
	fake.createSnapshotReturns = struct {
		result1 *snapshots.Snapshot
		result2 error
	}{result1, result2}
}

func (fake *FakeVolumeFacade) CreateSnapshotReturnsOnCall(i int, result1 *snapshots.Snapshot, result2 error) {
	fake.createSnapshotMutex.Lock()
	defer fake.createSnapshotMutex.Unlock()
	fake.CreateSnapshotStub = nil
	if fake.createSnapshotReturnsOnCall == nil {
		fake.createSnapshotReturnsOnCall = make(map[int]struct {
			result1 *snapshots.Snapshot
			result2 error
		})
	}
	fake.createSnapshotReturnsOnCall[i] = struct {
		result1 *snapshots.Snapshot
		result2 error
	}{result1, result2}
}

func (fake *FakeVolumeFacade) CreateVolume(arg1 utils.ServiceClient, arg2 volumes.CreateOptsBuilder) (*volumes.Volume, error) {
	fake.createVolumeMutex.Lock()
	ret, specificReturn := fake.createVolumeReturnsOnCall[len(fake.createVolumeArgsForCall)]
	fake.createVolumeArgsForCall = append(fake.createVolumeArgsForCall, struct {
		arg1 utils.ServiceClient
		arg2 volumes.CreateOptsBuilder
	}{arg1, arg2})
	stub := fake.CreateVolumeStub
	fakeReturns := fake.createVolumeReturns
	fake.recordInvocation("CreateVolume", []interface{}{arg1, arg2})
	fake.createVolumeMutex.Unlock()
	if stub != nil {
		return stub(arg1, arg2)
	}
	if specificReturn {
		return ret.result1, ret.result2
	}
	return fakeReturns.result1, fakeReturns.result2
}

func (fake *FakeVolumeFacade) CreateVolumeCallCount() int {
	fake.createVolumeMutex.RLock()
	defer fake.createVolumeMutex.RUnlock()
	return len(fake.createVolumeArgsForCall)
}

func (fake *FakeVolumeFacade) CreateVolumeCalls(stub func(utils.ServiceClient, volumes.CreateOptsBuilder) (*volumes.Volume, error)) {
	fake.createVolumeMutex.Lock()
	defer fake.createVolumeMutex.Unlock()
	fake.CreateVolumeStub = stub
}

func (fake *FakeVolumeFacade) CreateVolumeArgsForCall(i int) (utils.ServiceClient, volumes.CreateOptsBuilder) {
	fake.createVolumeMutex.RLock()
	defer fake.createVolumeMutex.RUnlock()
	argsForCall := fake.createVolumeArgsForCall[i]
	return argsForCall.arg1, argsForCall.arg2
}

func (fake *FakeVolumeFacade) CreateVolumeReturns(result1 *volumes.Volume, result2 error) {
	fake.createVolumeMutex.Lock()
	defer fake.createVolumeMutex.Unlock()
	fake.CreateVolumeStub = nil
	fake.createVolumeReturns = struct {
		result1 *volumes.Volume
		result2 error
	}{result1, result2}
}

func (fake *FakeVolumeFacade) CreateVolumeReturnsOnCall(i int, result1 *volumes.Volume, result2 error) {
	fake.createVolumeMutex.Lock()
	defer fake.createVolumeMutex.Unlock()
	fake.CreateVolumeStub = nil
	if fake.createVolumeReturnsOnCall == nil {
		fake.createVolumeReturnsOnCall = make(map[int]struct {
			result1 *volumes.Volume
			result2 error
		})
	}
	fake.createVolumeReturnsOnCall[i] = struct {
		result1 *volumes.Volume
		result2 error
	}{result1, result2}
}

func (fake *FakeVolumeFacade) DeleteSnapshot(arg1 *gophercloud.ServiceClient, arg2 string) error {
	fake.deleteSnapshotMutex.Lock()
	ret, specificReturn := fake.deleteSnapshotReturnsOnCall[len(fake.deleteSnapshotArgsForCall)]
	fake.deleteSnapshotArgsForCall = append(fake.deleteSnapshotArgsForCall, struct {
		arg1 *gophercloud.ServiceClient
		arg2 string
	}{arg1, arg2})
	stub := fake.DeleteSnapshotStub
	fakeReturns := fake.deleteSnapshotReturns
	fake.recordInvocation("DeleteSnapshot", []interface{}{arg1, arg2})
	fake.deleteSnapshotMutex.Unlock()
	if stub != nil {
		return stub(arg1, arg2)
	}
	if specificReturn {
		return ret.result1
	}
	return fakeReturns.result1
}

func (fake *FakeVolumeFacade) DeleteSnapshotCallCount() int {
	fake.deleteSnapshotMutex.RLock()
	defer fake.deleteSnapshotMutex.RUnlock()
	return len(fake.deleteSnapshotArgsForCall)
}

func (fake *FakeVolumeFacade) DeleteSnapshotCalls(stub func(*gophercloud.ServiceClient, string) error) {
	fake.deleteSnapshotMutex.Lock()
	defer fake.deleteSnapshotMutex.Unlock()
	fake.DeleteSnapshotStub = stub
}

func (fake *FakeVolumeFacade) DeleteSnapshotArgsForCall(i int) (*gophercloud.ServiceClient, string) {
	fake.deleteSnapshotMutex.RLock()
	defer fake.deleteSnapshotMutex.RUnlock()
	argsForCall := fake.deleteSnapshotArgsForCall[i]
	return argsForCall.arg1, argsForCall.arg2
}

func (fake *FakeVolumeFacade) DeleteSnapshotReturns(result1 error) {
	fake.deleteSnapshotMutex.Lock()
	defer fake.deleteSnapshotMutex.Unlock()
	fake.DeleteSnapshotStub = nil
	fake.deleteSnapshotReturns = struct {
		result1 error
	}{result1}
}

func (fake *FakeVolumeFacade) DeleteSnapshotReturnsOnCall(i int, result1 error) {
	fake.deleteSnapshotMutex.Lock()
	defer fake.deleteSnapshotMutex.Unlock()
	fake.DeleteSnapshotStub = nil
	if fake.deleteSnapshotReturnsOnCall == nil {
		fake.deleteSnapshotReturnsOnCall = make(map[int]struct {
			result1 error
		})
	}
	fake.deleteSnapshotReturnsOnCall[i] = struct {
		result1 error
	}{result1}
}

func (fake *FakeVolumeFacade) DeleteVolume(arg1 utils.RetryableServiceClient, arg2 string, arg3 volumes.DeleteOptsBuilder) error {
	fake.deleteVolumeMutex.Lock()
	ret, specificReturn := fake.deleteVolumeReturnsOnCall[len(fake.deleteVolumeArgsForCall)]
	fake.deleteVolumeArgsForCall = append(fake.deleteVolumeArgsForCall, struct {
		arg1 utils.RetryableServiceClient
		arg2 string
		arg3 volumes.DeleteOptsBuilder
	}{arg1, arg2, arg3})
	stub := fake.DeleteVolumeStub
	fakeReturns := fake.deleteVolumeReturns
	fake.recordInvocation("DeleteVolume", []interface{}{arg1, arg2, arg3})
	fake.deleteVolumeMutex.Unlock()
	if stub != nil {
		return stub(arg1, arg2, arg3)
	}
	if specificReturn {
		return ret.result1
	}
	return fakeReturns.result1
}

func (fake *FakeVolumeFacade) DeleteVolumeCallCount() int {
	fake.deleteVolumeMutex.RLock()
	defer fake.deleteVolumeMutex.RUnlock()
	return len(fake.deleteVolumeArgsForCall)
}

func (fake *FakeVolumeFacade) DeleteVolumeCalls(stub func(utils.RetryableServiceClient, string, volumes.DeleteOptsBuilder) error) {
	fake.deleteVolumeMutex.Lock()
	defer fake.deleteVolumeMutex.Unlock()
	fake.DeleteVolumeStub = stub
}

func (fake *FakeVolumeFacade) DeleteVolumeArgsForCall(i int) (utils.RetryableServiceClient, string, volumes.DeleteOptsBuilder) {
	fake.deleteVolumeMutex.RLock()
	defer fake.deleteVolumeMutex.RUnlock()
	argsForCall := fake.deleteVolumeArgsForCall[i]
	return argsForCall.arg1, argsForCall.arg2, argsForCall.arg3
}

func (fake *FakeVolumeFacade) DeleteVolumeReturns(result1 error) {
	fake.deleteVolumeMutex.Lock()
	defer fake.deleteVolumeMutex.Unlock()
	fake.DeleteVolumeStub = nil
	fake.deleteVolumeReturns = struct {
		result1 error
	}{result1}
}

func (fake *FakeVolumeFacade) DeleteVolumeReturnsOnCall(i int, result1 error) {
	fake.deleteVolumeMutex.Lock()
	defer fake.deleteVolumeMutex.Unlock()
	fake.DeleteVolumeStub = nil
	if fake.deleteVolumeReturnsOnCall == nil {
		fake.deleteVolumeReturnsOnCall = make(map[int]struct {
			result1 error
		})
	}
	fake.deleteVolumeReturnsOnCall[i] = struct {
		result1 error
	}{result1}
}

func (fake *FakeVolumeFacade) ExtendVolumeSize(arg1 utils.ServiceClient, arg2 string, arg3 volumeactions.ExtendSizeOptsBuilder) error {
	fake.extendVolumeSizeMutex.Lock()
	ret, specificReturn := fake.extendVolumeSizeReturnsOnCall[len(fake.extendVolumeSizeArgsForCall)]
	fake.extendVolumeSizeArgsForCall = append(fake.extendVolumeSizeArgsForCall, struct {
		arg1 utils.ServiceClient
		arg2 string
		arg3 volumeactions.ExtendSizeOptsBuilder
	}{arg1, arg2, arg3})
	stub := fake.ExtendVolumeSizeStub
	fakeReturns := fake.extendVolumeSizeReturns
	fake.recordInvocation("ExtendVolumeSize", []interface{}{arg1, arg2, arg3})
	fake.extendVolumeSizeMutex.Unlock()
	if stub != nil {
		return stub(arg1, arg2, arg3)
	}
	if specificReturn {
		return ret.result1
	}
	return fakeReturns.result1
}

func (fake *FakeVolumeFacade) ExtendVolumeSizeCallCount() int {
	fake.extendVolumeSizeMutex.RLock()
	defer fake.extendVolumeSizeMutex.RUnlock()
	return len(fake.extendVolumeSizeArgsForCall)
}

func (fake *FakeVolumeFacade) ExtendVolumeSizeCalls(stub func(utils.ServiceClient, string, volumeactions.ExtendSizeOptsBuilder) error) {
	fake.extendVolumeSizeMutex.Lock()
	defer fake.extendVolumeSizeMutex.Unlock()
	fake.ExtendVolumeSizeStub = stub
}

func (fake *FakeVolumeFacade) ExtendVolumeSizeArgsForCall(i int) (utils.ServiceClient, string, volumeactions.ExtendSizeOptsBuilder) {
	fake.extendVolumeSizeMutex.RLock()
	defer fake.extendVolumeSizeMutex.RUnlock()
	argsForCall := fake.extendVolumeSizeArgsForCall[i]
	return argsForCall.arg1, argsForCall.arg2, argsForCall.arg3
}

func (fake *FakeVolumeFacade) ExtendVolumeSizeReturns(result1 error) {
	fake.extendVolumeSizeMutex.Lock()
	defer fake.extendVolumeSizeMutex.Unlock()
	fake.ExtendVolumeSizeStub = nil
	fake.extendVolumeSizeReturns = struct {
		result1 error
	}{result1}
}

func (fake *FakeVolumeFacade) ExtendVolumeSizeReturnsOnCall(i int, result1 error) {
	fake.extendVolumeSizeMutex.Lock()
	defer fake.extendVolumeSizeMutex.Unlock()
	fake.ExtendVolumeSizeStub = nil
	if fake.extendVolumeSizeReturnsOnCall == nil {
		fake.extendVolumeSizeReturnsOnCall = make(map[int]struct {
			result1 error
		})
	}
	fake.extendVolumeSizeReturnsOnCall[i] = struct {
		result1 error
	}{result1}
}

func (fake *FakeVolumeFacade) GetSnapshot(arg1 utils.RetryableServiceClient, arg2 string) (*snapshots.Snapshot, error) {
	fake.getSnapshotMutex.Lock()
	ret, specificReturn := fake.getSnapshotReturnsOnCall[len(fake.getSnapshotArgsForCall)]
	fake.getSnapshotArgsForCall = append(fake.getSnapshotArgsForCall, struct {
		arg1 utils.RetryableServiceClient
		arg2 string
	}{arg1, arg2})
	stub := fake.GetSnapshotStub
	fakeReturns := fake.getSnapshotReturns
	fake.recordInvocation("GetSnapshot", []interface{}{arg1, arg2})
	fake.getSnapshotMutex.Unlock()
	if stub != nil {
		return stub(arg1, arg2)
	}
	if specificReturn {
		return ret.result1, ret.result2
	}
	return fakeReturns.result1, fakeReturns.result2
}

func (fake *FakeVolumeFacade) GetSnapshotCallCount() int {
	fake.getSnapshotMutex.RLock()
	defer fake.getSnapshotMutex.RUnlock()
	return len(fake.getSnapshotArgsForCall)
}

func (fake *FakeVolumeFacade) GetSnapshotCalls(stub func(utils.RetryableServiceClient, string) (*snapshots.Snapshot, error)) {
	fake.getSnapshotMutex.Lock()
	defer fake.getSnapshotMutex.Unlock()
	fake.GetSnapshotStub = stub
}

func (fake *FakeVolumeFacade) GetSnapshotArgsForCall(i int) (utils.RetryableServiceClient, string) {
	fake.getSnapshotMutex.RLock()
	defer fake.getSnapshotMutex.RUnlock()
	argsForCall := fake.getSnapshotArgsForCall[i]
	return argsForCall.arg1, argsForCall.arg2
}

func (fake *FakeVolumeFacade) GetSnapshotReturns(result1 *snapshots.Snapshot, result2 error) {
	fake.getSnapshotMutex.Lock()
	defer fake.getSnapshotMutex.Unlock()
	fake.GetSnapshotStub = nil
	fake.getSnapshotReturns = struct {
		result1 *snapshots.Snapshot
		result2 error
	}{result1, result2}
}

func (fake *FakeVolumeFacade) GetSnapshotReturnsOnCall(i int, result1 *snapshots.Snapshot, result2 error) {
	fake.getSnapshotMutex.Lock()
	defer fake.getSnapshotMutex.Unlock()
	fake.GetSnapshotStub = nil
	if fake.getSnapshotReturnsOnCall == nil {
		fake.getSnapshotReturnsOnCall = make(map[int]struct {
			result1 *snapshots.Snapshot
			result2 error
		})
	}
	fake.getSnapshotReturnsOnCall[i] = struct {
		result1 *snapshots.Snapshot
		result2 error
	}{result1, result2}
}

func (fake *FakeVolumeFacade) GetVolume(arg1 utils.RetryableServiceClient, arg2 string) (*volumes.Volume, error) {
	fake.getVolumeMutex.Lock()
	ret, specificReturn := fake.getVolumeReturnsOnCall[len(fake.getVolumeArgsForCall)]
	fake.getVolumeArgsForCall = append(fake.getVolumeArgsForCall, struct {
		arg1 utils.RetryableServiceClient
		arg2 string
	}{arg1, arg2})
	stub := fake.GetVolumeStub
	fakeReturns := fake.getVolumeReturns
	fake.recordInvocation("GetVolume", []interface{}{arg1, arg2})
	fake.getVolumeMutex.Unlock()
	if stub != nil {
		return stub(arg1, arg2)
	}
	if specificReturn {
		return ret.result1, ret.result2
	}
	return fakeReturns.result1, fakeReturns.result2
}

func (fake *FakeVolumeFacade) GetVolumeCallCount() int {
	fake.getVolumeMutex.RLock()
	defer fake.getVolumeMutex.RUnlock()
	return len(fake.getVolumeArgsForCall)
}

func (fake *FakeVolumeFacade) GetVolumeCalls(stub func(utils.RetryableServiceClient, string) (*volumes.Volume, error)) {
	fake.getVolumeMutex.Lock()
	defer fake.getVolumeMutex.Unlock()
	fake.GetVolumeStub = stub
}

func (fake *FakeVolumeFacade) GetVolumeArgsForCall(i int) (utils.RetryableServiceClient, string) {
	fake.getVolumeMutex.RLock()
	defer fake.getVolumeMutex.RUnlock()
	argsForCall := fake.getVolumeArgsForCall[i]
	return argsForCall.arg1, argsForCall.arg2
}

func (fake *FakeVolumeFacade) GetVolumeReturns(result1 *volumes.Volume, result2 error) {
	fake.getVolumeMutex.Lock()
	defer fake.getVolumeMutex.Unlock()
	fake.GetVolumeStub = nil
	fake.getVolumeReturns = struct {
		result1 *volumes.Volume
		result2 error
	}{result1, result2}
}

func (fake *FakeVolumeFacade) GetVolumeReturnsOnCall(i int, result1 *volumes.Volume, result2 error) {
	fake.getVolumeMutex.Lock()
	defer fake.getVolumeMutex.Unlock()
	fake.GetVolumeStub = nil
	if fake.getVolumeReturnsOnCall == nil {
		fake.getVolumeReturnsOnCall = make(map[int]struct {
			result1 *volumes.Volume
			result2 error
		})
	}
	fake.getVolumeReturnsOnCall[i] = struct {
		result1 *volumes.Volume
		result2 error
	}{result1, result2}
}

func (fake *FakeVolumeFacade) SetDiskMetadata(arg1 utils.ServiceClient, arg2 string, arg3 volumes.UpdateOptsBuilder) error {
	fake.setDiskMetadataMutex.Lock()
	ret, specificReturn := fake.setDiskMetadataReturnsOnCall[len(fake.setDiskMetadataArgsForCall)]
	fake.setDiskMetadataArgsForCall = append(fake.setDiskMetadataArgsForCall, struct {
		arg1 utils.ServiceClient
		arg2 string
		arg3 volumes.UpdateOptsBuilder
	}{arg1, arg2, arg3})
	stub := fake.SetDiskMetadataStub
	fakeReturns := fake.setDiskMetadataReturns
	fake.recordInvocation("SetDiskMetadata", []interface{}{arg1, arg2, arg3})
	fake.setDiskMetadataMutex.Unlock()
	if stub != nil {
		return stub(arg1, arg2, arg3)
	}
	if specificReturn {
		return ret.result1
	}
	return fakeReturns.result1
}

func (fake *FakeVolumeFacade) SetDiskMetadataCallCount() int {
	fake.setDiskMetadataMutex.RLock()
	defer fake.setDiskMetadataMutex.RUnlock()
	return len(fake.setDiskMetadataArgsForCall)
}

func (fake *FakeVolumeFacade) SetDiskMetadataCalls(stub func(utils.ServiceClient, string, volumes.UpdateOptsBuilder) error) {
	fake.setDiskMetadataMutex.Lock()
	defer fake.setDiskMetadataMutex.Unlock()
	fake.SetDiskMetadataStub = stub
}

func (fake *FakeVolumeFacade) SetDiskMetadataArgsForCall(i int) (utils.ServiceClient, string, volumes.UpdateOptsBuilder) {
	fake.setDiskMetadataMutex.RLock()
	defer fake.setDiskMetadataMutex.RUnlock()
	argsForCall := fake.setDiskMetadataArgsForCall[i]
	return argsForCall.arg1, argsForCall.arg2, argsForCall.arg3
}

func (fake *FakeVolumeFacade) SetDiskMetadataReturns(result1 error) {
	fake.setDiskMetadataMutex.Lock()
	defer fake.setDiskMetadataMutex.Unlock()
	fake.SetDiskMetadataStub = nil
	fake.setDiskMetadataReturns = struct {
		result1 error
	}{result1}
}

func (fake *FakeVolumeFacade) SetDiskMetadataReturnsOnCall(i int, result1 error) {
	fake.setDiskMetadataMutex.Lock()
	defer fake.setDiskMetadataMutex.Unlock()
	fake.SetDiskMetadataStub = nil
	if fake.setDiskMetadataReturnsOnCall == nil {
		fake.setDiskMetadataReturnsOnCall = make(map[int]struct {
			result1 error
		})
	}
	fake.setDiskMetadataReturnsOnCall[i] = struct {
		result1 error
	}{result1}
}

func (fake *FakeVolumeFacade) UpdateMetaDataSnapShot(arg1 *gophercloud.ServiceClient, arg2 string, arg3 snapshots.UpdateMetadataOptsBuilder) (map[string]interface{}, error) {
	fake.updateMetaDataSnapShotMutex.Lock()
	ret, specificReturn := fake.updateMetaDataSnapShotReturnsOnCall[len(fake.updateMetaDataSnapShotArgsForCall)]
	fake.updateMetaDataSnapShotArgsForCall = append(fake.updateMetaDataSnapShotArgsForCall, struct {
		arg1 *gophercloud.ServiceClient
		arg2 string
		arg3 snapshots.UpdateMetadataOptsBuilder
	}{arg1, arg2, arg3})
	stub := fake.UpdateMetaDataSnapShotStub
	fakeReturns := fake.updateMetaDataSnapShotReturns
	fake.recordInvocation("UpdateMetaDataSnapShot", []interface{}{arg1, arg2, arg3})
	fake.updateMetaDataSnapShotMutex.Unlock()
	if stub != nil {
		return stub(arg1, arg2, arg3)
	}
	if specificReturn {
		return ret.result1, ret.result2
	}
	return fakeReturns.result1, fakeReturns.result2
}

func (fake *FakeVolumeFacade) UpdateMetaDataSnapShotCallCount() int {
	fake.updateMetaDataSnapShotMutex.RLock()
	defer fake.updateMetaDataSnapShotMutex.RUnlock()
	return len(fake.updateMetaDataSnapShotArgsForCall)
}

func (fake *FakeVolumeFacade) UpdateMetaDataSnapShotCalls(stub func(*gophercloud.ServiceClient, string, snapshots.UpdateMetadataOptsBuilder) (map[string]interface{}, error)) {
	fake.updateMetaDataSnapShotMutex.Lock()
	defer fake.updateMetaDataSnapShotMutex.Unlock()
	fake.UpdateMetaDataSnapShotStub = stub
}

func (fake *FakeVolumeFacade) UpdateMetaDataSnapShotArgsForCall(i int) (*gophercloud.ServiceClient, string, snapshots.UpdateMetadataOptsBuilder) {
	fake.updateMetaDataSnapShotMutex.RLock()
	defer fake.updateMetaDataSnapShotMutex.RUnlock()
	argsForCall := fake.updateMetaDataSnapShotArgsForCall[i]
	return argsForCall.arg1, argsForCall.arg2, argsForCall.arg3
}

func (fake *FakeVolumeFacade) UpdateMetaDataSnapShotReturns(result1 map[string]interface{}, result2 error) {
	fake.updateMetaDataSnapShotMutex.Lock()
	defer fake.updateMetaDataSnapShotMutex.Unlock()
	fake.UpdateMetaDataSnapShotStub = nil
	fake.updateMetaDataSnapShotReturns = struct {
		result1 map[string]interface{}
		result2 error
	}{result1, result2}
}

func (fake *FakeVolumeFacade) UpdateMetaDataSnapShotReturnsOnCall(i int, result1 map[string]interface{}, result2 error) {
	fake.updateMetaDataSnapShotMutex.Lock()
	defer fake.updateMetaDataSnapShotMutex.Unlock()
	fake.UpdateMetaDataSnapShotStub = nil
	if fake.updateMetaDataSnapShotReturnsOnCall == nil {
		fake.updateMetaDataSnapShotReturnsOnCall = make(map[int]struct {
			result1 map[string]interface{}
			result2 error
		})
	}
	fake.updateMetaDataSnapShotReturnsOnCall[i] = struct {
		result1 map[string]interface{}
		result2 error
	}{result1, result2}
}

func (fake *FakeVolumeFacade) Invocations() map[string][][]interface{} {
	fake.invocationsMutex.RLock()
	defer fake.invocationsMutex.RUnlock()
	fake.createSnapshotMutex.RLock()
	defer fake.createSnapshotMutex.RUnlock()
	fake.createVolumeMutex.RLock()
	defer fake.createVolumeMutex.RUnlock()
	fake.deleteSnapshotMutex.RLock()
	defer fake.deleteSnapshotMutex.RUnlock()
	fake.deleteVolumeMutex.RLock()
	defer fake.deleteVolumeMutex.RUnlock()
	fake.extendVolumeSizeMutex.RLock()
	defer fake.extendVolumeSizeMutex.RUnlock()
	fake.getSnapshotMutex.RLock()
	defer fake.getSnapshotMutex.RUnlock()
	fake.getVolumeMutex.RLock()
	defer fake.getVolumeMutex.RUnlock()
	fake.setDiskMetadataMutex.RLock()
	defer fake.setDiskMetadataMutex.RUnlock()
	fake.updateMetaDataSnapShotMutex.RLock()
	defer fake.updateMetaDataSnapShotMutex.RUnlock()
	copiedInvocations := map[string][][]interface{}{}
	for key, value := range fake.invocations {
		copiedInvocations[key] = value
	}
	return copiedInvocations
}

func (fake *FakeVolumeFacade) recordInvocation(key string, args []interface{}) {
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

var _ volume.VolumeFacade = new(FakeVolumeFacade)
