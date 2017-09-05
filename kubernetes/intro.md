# Kubernetes 简介与安装


## 组件

整体结构如下图:

![arch](img/arch.png)

以下简单介绍下各模块：
### master 组件
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

### node 组件
- kubelet    
  kubelet 是主要的 node 客户端服务，其提供 pod 相关的操作。
- kube-proxy   
  管理 service 的入口，kube-proxy 允许 kubernetes 服务进行网络连接的转发。
- docker   
  用来运行容器。
- supervisord   
  用于守护 kubelet 和 docker 运行。

## 安装
### 条件
在正式安装前，确保如下几点满足条件：
- 服务器操作系统版本为 Ubuntu16.04+，CentOS7 或 HypriotOS v1.0.1+
- 每台服务器至少 1GB 内存
- 服务器间网络互通
- 关闭防火墙
  命令如下：
  ```
  $ sudo setenforce 0
  $ sudo systemctl disable iptables-services firewalld
  $ sudo systemctl stop iptables-services firewalld
  ``` 
- 如下端口可用
  Node type | Port | Purpose
 -----------|-----------|-----------
  Master    | 6443      | Kubernetes API Server
  Master    | 2379-2380 | etcd Server Client API
  Master/Node    | 10250     | Kubelet API
  Master    | 10251     | kube-scheduler
  Master    | 10252     | kube-controller-manager
  Master/Node      | 10255     | Read-only Kubelet API (Heapster)
  Node      | 30000-32767 | Node 上服务随机使用的端口


本次测试机器情况如下：
 Hostname | OS | Memory | Network | Port
---------|-------|--------|------|---------
 svr001  | CentOS7.1 | 128G | 满足条件 | 满足条件
 svr002  | CentOS7.1 | 128G | 满足条件 | 满足条件
 svr003  | CentOS7.1 | 128G | 满足条件 | 满足条件

### 安装 Docker
在安装 Kubernetes 前，先安装 Docker，由于 docker 依赖的 `container-selinux` 包在 extras repo 中，因此需要先将该repo开启（默认开启）。执行命令如下：
```
// 开启 extras
$ sudo yum-config-manager --enable extras
$ sudo yum install -y yum-utils device-mapper-persistent-data lvm2
$ sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
$ sudo yum makecache fast
$ sudo yum install docker-ce
$ yum list docker-ce.x86_64  --showduplicates | sort -r
$ sudo systemctl start docker
$ sudo docker run hello-world
```
若 yum 无法访问外网，需在 /etc/yum.conf 中设置 proxy 代理。

### 安装 Kubernetes

安装 kubernetes 的方式较多，比如官网上使用 kubectl 进行安装。若希望开发或调试 kubernetes，可通过编译安装。这里使用[二进制预编译包](https://github.com/kubernetes/kubernetes/releases)安装。下载最新版 kubernetes 后解压，如下：
```
$ cd kubernetes/cluster
$ ./get-kube-binaries.sh
$ cd ../server
$ tar xvzf kubernetes-server-linux-amd64.tar.gz
$ sudo mv kubernetes /opt/app/
```
修改 PATH，添加 kubernetes 中 bin 目录。

接下来安装 etcd 和 flannel。下载 [etcd](https://github.com/coreos/etcd/releases)，[flannel](https://github.com/coreos/flannel/releases)，解压后将 flanneld, mk-docker-opts.sh, etcd, etcdctl 移动到 /opt/app/kubernetes/server/bin 目录下，此时 kubernetes 各组件安装完成，接着进行配置。




## 报错
在安装过程中，有如下几个报错，以下分别是解决过程
### docker 依赖 
```
$ sudo yum install docker-ce
...
Error: Package: docker-ce-17.06.1.ce-1.el7.centos.x86_64 (docker-ce-stable)
           Requires: libdevmapper.so.1.02(DM_1_02_97)(64bit)
Error: Package: docker-ce-17.06.1.ce-1.el7.centos.x86_64 (docker-ce-stable)
           Requires: container-selinux >= 2.9
 You could try using --skip-broken to work around the problem
```

这个原因在 [Get Docker EE for Red Hat Enterprise Linux](https://docs.docker.com/engine/installation/linux/docker-ee/rhel/) 找到答案：
> Enable the extras RHEL repository. This ensures access to the `container-selinux` package which is required by docker-ee.

查看 /etc/yum.repos.d 中 extras 相关的repo文件，打开 extras 对应的 baseurl，未发现 `container-selinux`，查看 [CentOS7 extras repo](http://mirror.centos.org/centos/7/extras/x86_64/Packages/)，能找到 container-selinux-2.19 等，于是在 /etc/yum.repos.d 中新建 repo 源，拷贝阿里的 yum 源：`wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo`。再 `yum makecache`后，重新安装，解决问题。解决方法业已在 [Docs to be updated for container-selinux](https://github.com/docker/for-linux/issues/21)提及。

## 参考
- [CentOS install Kubernetes](https://kubernetes.io/docs/getting-started-guides/centos/centos_manual_config/)
- [Get Docker CE for CentOS](https://docs.docker.com/engine/installation/linux/docker-ce/centos/)
