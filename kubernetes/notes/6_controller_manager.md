# Controller Manager

Controller Manager 是 Kubernetes 集群的管理控制中心，其主要负责 Node, Pod, Endpoint, Namespace 等的管理。Controller Manager 是一个控制循环，通过 apiserver 监视集群的共享状态，并通过更改操作尝试将当前状态变更为所需状态。

依然从 [cmd/kube-controller-manager/controller-manager.go](https://github.com/kubernetes/kubernetes/blob/release-1.13/cmd/kube-controller-manager/controller-manager.go) 开始分析。其调用 [NewControllerManagerCommand()](https://github.com/kubernetes/kubernetes/blob/release-1.13/cmd/kube-controller-manager/app/controllermanager.go#L81) 生成 controller manager 的 command。

查看 command 的 [Run()](https://github.com/kubernetes/kubernetes/blob/release-1.13/cmd/kube-controller-manager/app/controllermanager.go#L148)，其主要做了如下事情：
- 启动 HTTP 和/或 HTTPS 服务。
- 调用 [https://github.com/kubernetes/kubernetes/blob/release-1.13/cmd/kube-controller-manager/app/controllermanager.go#L360](https://github.com/kubernetes/kubernetes/blob/release-1.13/cmd/kube-controller-manager/app/controllermanager.go#L360) 设置 Controller，此方法设置了需要启动的 controller 类型。然后调用 [StartControllers](https://github.com/kubernetes/kubernetes/blob/release-1.13/cmd/kube-controller-manager/app/controllermanager.go#L480) 启动设置的 controller。另外还可以看到，[NewControllerManagerCommand()](https://github.com/kubernetes/kubernetes/blob/release-1.13/cmd/kube-controller-manager/app/controllermanager.go#L102) 设置了默认不启动的 Controller：`bootstrapsigner` 和 `tokencleaner`。
- 为启动的 controller manager 设置 ID（值为 `id + "_" + string(uuid.NewUUID())`）。
- 进行 kube-controller-manager 的选主操作。
