# CNI

CNI（Container Network Interface）是 CNCF 旗下的一个项目，由一组配置容器网络接口的规范和库及一些插件组成。项目地址：[cni](https://github.com/containernetworking/cni)。

从项目文档中可以看到，CNI 的容器运行时包括：rkt, Kubernetes, Apache Mesos, Amazon EC2 等。常用的第三方插件实现有：Calico, Waeve, SR-IOV, DANM 等等。

当前 Kubernetes 1.13.0 使用的是 v0.6.0 的 CNI，所以这里以 v0.6.0 为例，说下 CNI 的大致结构。


## CNI 接口定义
查看 `libcni/api.go` 下的 CNI 接口定义，非常简单：

```
type CNI interface {
	AddNetworkList(net *NetworkConfigList, rt *RuntimeConf) (types.Result, error)
	DelNetworkList(net *NetworkConfigList, rt *RuntimeConf) error

	AddNetwork(net *NetworkConfig, rt *RuntimeConf) (types.Result, error)
	DelNetwork(net *NetworkConfig, rt *RuntimeConf) error
}
```

该接口只有四个方法：添加网络、删除网络、添加网络列表、删除网络列表。


## CNI 插件
CNI 项目组还维护了一系列实现 CNI 声明的相关[插件](https://github.com/containernetworking/plugins)。可以看到这些插件主要分为三大类：

### Main -- 创建接口
- bridge：创建网桥，并添加主机和容器到该网桥。
- ipvlan：在容器中添加一个 [ipvlan](https://www.kernel.org/doc/Documentation/networking/ipvlan.txt) 接口。
- loopback：启动回环接口。
- macvlan：创建新的 MAC 地址，将所有的流量转发给容器。
- ptp: 创建veth 对。
- vlan: 分配一个 vlan 设备。
- host-device: 将已经存在的设置移动到容器。

#### Windows 专用
- win-bridge: 创建网桥，并添加主机和容器到该网桥。
- win-overlay: 为容器创建 overlay 接口。

### IPAM -- 分配 IP 
- dhcp: 在主机上运行守护程序，代表容器发出 DHCP 请求。
- host-local: 维护一个分配 IP 的本地数据库。
- static: 为容器分配一个静态的 IPv4/IPv6 地址。

### Meta -- 其他插件
- flannel: 根据flannel的配置文件创建接口。
- tuning: Tweaks sysctl parameters of an existing interface
- portmap: An iptables-based portmapping plugin. Maps ports from the host's address space to the container.
- bandwidth: Allows bandwidth-limiting through use of traffic control tbf (ingress/egress).
- sbr: A plugin that configures source based routing for an interface (from which it is chained).
  
