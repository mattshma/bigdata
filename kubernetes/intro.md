# Kubernetes 简介与安装


## 组件

整体结构如下图:

![arch](img/arch.png)

以下简单介绍下各模块：
- kube-apiserver   
  kube-apiserver 提供了 api 功能，相当于 kubernetes crontrol plane 的前端部分。
- etcd   
  etcd 做为 kubernetes 的后端存储部分，集群所有数据都存放在这里，所以一般而言需备份 etcd 数据。
- kube-controller-manager   
  controller 是处理任务的后台进程，kuber-controller-manager 管理这些 controller。理论上讲每个 controller 都应是一个单独的线程，不过为方便起见，kubernetes 将所有 controller 都放在一个进程中运行。controller 有如下几类：
  - Node Controller: 用来通知并响应何时 node 下线。
  - Replication Controller: 管理 pod 的正确数量。
  - Endpoints Controller: 产生 endpoint 对象。
  - Service Account & Token Controller: 创建账户和 token。
- kube-scheduler    
  给创建的 pod 指定 node
- kubelet    
  kubelet 是主要的 node 客户端服务，其提供 pod 相关的操作。
- kube-proxy   
  管理 service 的入口，kube-proxy 允许 kubernetes 服务进行网络连接的转发。
- docker   
  用来运行容器。

