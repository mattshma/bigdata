# Device Plugin

当前原生 Kuberenetes 只支持 CPU 和 Memory 资源的管理。其他设备如 GPU、FPGA、Infiniband 等需要通过 Kubernetes 管理的话，只需要通过 Device Plugin 的方式。

## 简介

Device Plugin 是一个运行在容器中的 gRPC 服务器，通过实现如下两个函数，Device Plugin 与 kubelet 进行交互：
- `ListAndWatch` 方法用于 kubelet 发现设备及其属性以及通知任何状态的变化。           
- `Allocate` 方法在创建容器使用任何导出设备（exported devices）前调用。        

Device Plugin 的另一个流程即 `Registration`，用于向 kubelet 发起注册请求。Device Plugin 的大致流程如下：

![device plugin overview](img/device-plugin-overview.png)

- `Registration` 阶段         

当启动 Device Plugin 时，其先通过 `Register` 方法向 kubelet 发起一个 `RegisterRequest` 请求（gRPC 请求），然后 kubelet 返回一个包含 kublet 遇到任何 error 的 `RegisterResponse`，若 Device Plugin 没收到任何 error，则启动 gRPC 服务器。

  Device Plugin 通过 Unix socket 与 kubelet 交互，在启动 gRPC 服务器的过程中，其会在 `/var/lib/kubelet/device-plugins/` 这个目录下创建一个 Unix socket。
 
  在初次注册到 kubelet 过程中，Device Plugin 将会发送如下内容：               
    - 使用的 Unix socket 的名称      
    - 构建的 API 版本信息          
    - 想要发布的 `ResourceName`             

  kubelet 返回是否有报错，报错包括但不限于 api 版本不支持，`ResourceName` 已注册等。               
- `Discovery` 阶段          
  注册成功后，`ListAndWatch` 方法公布一组 Device 信息给 kubelet，若 Device 状态变更，该方法重新发布信息。            
- `Allocation` 阶段      
  若容器需要使用 Device Plugin 宣称的资源，则在启动容器前调用 `Allocate` 方法。              
- `Stop` 阶段      
  卸载 drivers。

### API 

```
// Registration is the service advertised by the Kubelet
// Only when Kubelet answers with a success code to a Register Request
// may Device Plugins start their service
// Registration may fail when device plugin version is not supported by
// Kubelet or the registered resourceName is already taken by another
// active device plugin. Device plugin is expected to terminate upon registration failure
service Registration {
	rpc Register(RegisterRequest) returns (Empty) {}
}

// DevicePlugin is the service advertised by Device Plugins
service DevicePlugin {
	// ListAndWatch returns a stream of List of Devices
	// Whenever a Device state change or a Device disappears, ListAndWatch
	// returns the new list
	rpc ListAndWatch(Empty) returns (stream ListAndWatchResponse) {}

	// Allocate is called during container creation so that the Device
	// Plugin can run device specific operations and instruct Kubelet
	// of the steps to make the Device available in the container
	rpc Allocate(AllocateRequest) returns (AllocateResponse) {}
}

message RegisterRequest {
	// Version of the API the Device Plugin was built against
	string version = 1;
	// Name of the unix socket the device plugin is listening on
	// PATH = path.Join(DevicePluginPath, endpoint)
	string endpoint = 2;
	// Schedulable resource name
	string resource_name = 3;
}

// - Allocate is expected to be called during pod creation since allocation
//   failures for any container would result in pod startup failure.
// - Allocate allows kubelet to exposes additional artifacts in a pod's
//   environment as directed by the plugin.
// - Allocate allows Device Plugin to run device specific operations on
//   the Devices requested
message AllocateRequest {
	repeated string devicesIDs = 1;
}

// Failure Handling:
// if Kubelet sends an allocation request for dev1 and dev2.
// Allocation on dev1 succeeds but allocation on dev2 fails.
// The Device plugin should send a ListAndWatch update and fail the
// Allocation request
message AllocateResponse {
	repeated DeviceRuntimeSpec spec = 1;
}

// ListAndWatch returns a stream of List of Devices
// Whenever a Device state change or a Device disappears, ListAndWatch
// returns the new list
message ListAndWatchResponse {
	repeated Device devices = 1;
}

// The list to be added to the CRI spec
message DeviceRuntimeSpec {
	string ID = 1;

	// List of environment variable to set in the container.
	map<string, string> envs = 2;
	// Mounts for the container.
	repeated Mount mounts = 3;
	// Devices for the container
	repeated DeviceSpec devices = 4;
}

// DeviceSpec specifies a host device to mount into a container.
message DeviceSpec {
    // Path of the device within the container.
    string container_path = 1;
    // Path of the device on the host.
    string host_path = 2;
    // Cgroups permissions of the device, candidates are one or more of
    // * r - allows container to read from the specified device.
    // * w - allows container to write to the specified device.
    // * m - allows container to create device files that do not yet exist.
    string permissions = 3;
}

// Mount specifies a host volume to mount into a container.
// where device library or tools are installed on host and container
message Mount {
	// Path of the mount on the host.
	string host_path = 1;
	// Path of the mount within the container.
	string mount_path = 2;
	// If set, the mount is read-only.
	bool read_only = 3;
}

// E.g:
// struct Device {
//    ID: "GPU-fef8089b-4820-abfc-e83e-94318197576e",
//    State: "Healthy",
//}
message Device {
	string ID = 2;
	string health = 3;
}

```

![device plugin](img/device-plugin.png)

### 健康检测及灾难恢复

如果有异常情况出现，Device Plugin 应发送 `ListAndWatch` gRPC 流，此时表明我们希望 kubelet 让 pod 变为 fail 状态，此时 pod 取决于 kubelet 正在执行的任务：
- 通常希望 kubelet 从节点容量中删除故障设备所拥有的任何设备。
- 但不希望 kubelet 失败或重启正在使用这些设备的任何 pod 或容器。
- 如果 kubelet 正在分配设备，那么应该使容器设备失败。

## k8s-device-plugin
这里以 nvidia/k8s-device-plugin 为例说下如何使用 Device Plugin。

## 参考
- [Device Manager Proposal](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/resource-management/device-plugin.md)
- [Device Plugin](https://kubernetes.io/zh/docs/concepts/cluster-administration/device-plugins/)
