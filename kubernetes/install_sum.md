# 部署 Kubernetes + Docker + TensorFlow/Caffe on GPU

## 目标
说明：机器为内网服务器，无法访问外网，假设代理服务器地址为：http://myproxy:8080，这里以该代理服务器访问外网。

网络：Flannel
ETCD: 单节点。多节点操作类似，这里为减少操作，以单节点描述。

## 操作过程
### 设置代理
编辑 `/etc/environment`，输入如下内容：
```
export http_proxy=http://myproxy:8080
export https_proxy=http://myproxy:8080
```
执行命令 `source /etc/environment` 加载配置。

### 安装 etcd
- 下载 [etcd](https://github.com/coreos/etcd/releases)，执行如下命令：
```
$ tar xvzf etcd-v3.2.7-linux-amd64.tar.gz
$ cd etcd-v3.2.7-linux-amd64
$ sudo mv etcd /usr/bin
$ sudo mv etcdctl /usr/bin
$ sudo mkdir /etc/etcd
```
- 配置 etcd
新建 `/etc/etcd/etcd.conf`，内容如下：
```
ETCD_NAME=srv001
ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"
ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379,http://0.0.0.0:4001"

# [cluster]
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://10.8.217.86:2380"
ETCD_INITIAL_CLUSTER="dps86=http://10.8.217.86:2380,dps87=http://10.8.217.87:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_ADVERTISE_CLIENT_URLS="http://10.8.217.86:2379,http://10.8.217.86:4001"
```
- 配置 etcd.service
新建文件 `/usr/lib/systemd/system/etcd.service`，内容如下：
```
[Unit]
Description=Etcd Server
After=network.target

[Service]
Type=notify
WorkingDirectory=/var/lib/etcd/
EnvironmentFile=/etc/etcd/etcd.conf
ExecStart=/usr/bin/etcd

[Install]
WantedBy=multi-user.target
```
- 启动 etcd
招行命令如下：
```
// 创建 etcd 工作目录
$ sudo mkdir /var/lib/etcd
// 启动 etcd 服务
$ sudo systemctl daemon-reload
$ sudo systemctl start etcd
$ sudo systemctl enable etcd
// 配置 Flanneld 网络
$ etcdctl set /kube/network/config '{"Network": "172.30.0.0/16", "SubnetLen": 24, "Backend": {"Type": "vxlan"}}'
```

### 安装 Flannel
- 下载 [flannel](https://github.com/coreos/flannel/releases)，执行如下命令：
```
$ tar xvzf flannel-v0.8.0-linux-amd64.tar.gz
$ sudo mv flanneld /usr/bin
$ sudo mv mk-docker-opts.sh /usr/bin
```
- 设置 Flanneld 配置文件
新建文件 `/etc/sysconfig/flanneld`，内容如下：
```
FLANNELD_ETCD_ENDPOINTS="http://10.8.217.88:2379"
FLANNELD_ETCD_PREFIX="/kube-centos/network"
```
- 设置 Flanneld.service 
新建文件 `/usr/lib/systemd/system/flanneld.service`，内容如下：
```
[Unit]
Description=Flanneld overlay address etcd agent
After=network.target
After=network-online.target
Wants=network-online.target
Before=docker.service

[Service]
Type=notify
EnvironmentFile=/etc/sysconfig/flanneld
EnvironmentFile=-/etc/sysconfig/docker-network
ExecStart=/usr/bin/flanneld $FLANNEL_OPTIONS
ExecStartPost=/usr/bin/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/docker
Restart=on-failure

[Install]
WantedBy=multi-user.target
RequiredBy=docker.service
```
- 启动 Flanneld
命令如下：
```
$ sudo systemctl daemon-reload
$ sudo systemctl start flanneld
$ sudo systemctl enable flanneld
$ $ ip a |grep -A 6 flannel
5: flannel.1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UNKNOWN
    link/ether 36:43:0f:7d:04:da brd ff:ff:ff:ff:ff:ff
    inet 172.30.72.0/32 scope global flannel.1
       valid_lft forever preferred_lft forever
    inet6 fe80::3443:fff:fe7d:4da/64 scope link
       valid_lft forever preferred_lft forever
```

### 安装 Docker
- 安装 docker
招行命令如下：
```
$ sudo yum-config-manager --enable extras
$ sudo yum -y install yum-utils device-mapper-persistent-data lvm2
$ sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
$ sudo mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
$ sudo wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.163.com/.help/CentOS7-Base-163.repo
$ sudo yum makecache fast
$ sudo yum -y install docker-ce
$ yum list docker-ce.x86_64  --showduplicates | sort -r
$ sudo systemctl start docker
$ sudo docker run hello-world
```
- 配置 docker
创建文件：`/etc/sysconfig/docker`，内容如下：
```
OPTIONS="-H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock --registry-mirror=xxxx --insecure-registry=xxx --insecure-registry=xxx"
```

- 配置 docker 网络
由于使用了 flannel，所以还需配置 docker.service，如下：
```
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target

[Service]
Type=notify
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
EnvironmentFile=/run/flannel/docker
EnvironmentFile=-/etc/sysconfig/docker
ExecStart=/usr/bin/dockerd $DOCKER_NETWORK_OPTIONS $OPTIONS
ExecReload=/bin/kill -s HUP $MAINPID
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
# Uncomment TasksMax if your systemd version supports it.
# Only systemd 226 and above support this version.
#TasksMax=infinity
TimeoutStartSec=0
# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes
# kill only the docker process, not all processes in the cgroup
KillMode=process
# restart the docker process if it exits prematurely
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
```
- 启动 docker
执行命令如下：
```
$ sudo systemctl daemon-reload
$ sudo systemctl disable docker
$ sudo systemctl start docker
$ sudo systemctl enable docker
$ sudo systemctl status docker
```

### 安装 Kubernetes
#### 下载 Kubernetes 并安装
下载 [Kubernetes](https://github.com/kubernetes/kubernetes/releases)，解压后进入 kubernetes/cluster 目录，编辑 get-kube-binaries.sh，在该文件头部设置代理服务器，如下：
```
#!/usr/bin/env bash

export http_proxy=http://myproxy:8080
export https_proxy=http://myproxy:8080
```
保存后运行 get-kube-binaries.sh，输入 y 安装。安装成功后招行如下命令：
```
$ cd ../server
$ tar vzxf kubernetes-server-linux-amd64.tar.gz
$ cd kubernetes/server/bin
$ rm *.tar *_tag
$ sudo chmod 755 *
$ sudo cp * /usr/bin
```

#### 从节点
- 设置 Kubernetes
创建目录：`/etc/kubernetes`，分别创建文件如下：
- /etc/kubernetes/config，内容如下：
```
# logging to stderr means we get it in the systemd journal
KUBE_LOGTOSTDERR="--logtostderr=true"

# journal message level, 0 is debug
KUBE_LOG_LEVEL="--v=0"

# Should this cluster be allowed to run privileged docker containers
KUBE_ALLOW_PRIV="--allow-privileged=true"

# How the replication controller and scheduler find the kube-apiserver
KUBE_MASTER="--master=http://10.8.217.86:8080"
```

- /etc/kubernetes/kubelet，内容如下：
```
# /etc/kubernetes/kubelet
KUBELET_ADDRESS="--address=0.0.0.0"
KUBELET_PORT="--port=10250"
KUBELET_ALLOW_PRI="--allow-privileged=true"
KUBELET_POD_INFRA_CONTAINER="--pod-infra-container-image=xxx/xxx/pod-infrastructure:v3.5.5.26-2"
# 若 KUBELET_HOSTNAME 值为 ""，则使用 Node 节点的 Hostname 做 Kubelet 的 Hostname。
#KUBELET_HOSTNAME=""
# kubelet_api_server="--api-servers=http://10.8.122.167:8080"
KUBELET_API_SERVER="--api-servers=http://10.8.217.86:8080"
KUBELET_ARGS='--cluster-domain=cluster.local --cluster-dns=10.254.0.2 --feature-gates="Accelerators=true"'
```

- /etc/kubernetes/proxy，内容如下：
```
KUBE_PROXY_ARGS='--feature-gates="Accelerators=true"'
```

- /usr/lib/systemd/system/kubelet.service，内容如下：
```
[Unit]
Description=Kubernetes Kubelet Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
WorkingDirectory=/var/lib/kubelet
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/kubelet
ExecStart=/usr/bin/kubelet \
           $KUBE_LOGTOSTDERR \
           $KUBE_LOG_LEVEL \
           $KUBELET_API_SERVER \
           $KUBELET_ADDRESS \
           $KUBELET_PORT \
           $KUBELET_HOSTNAME \
           $KUBE_ALLOW_PRIV \
           $KUBELET_POD_INFRA_CONTAINER \
           $KUBELET_ARGS
Restart=on-failure
KillMode=process

[Install]
WantedBy=multi-user.target
```

- /usr/lib/systemd/system/kube-proxy.service，内容如下：
```
[Unit]
Description=Kubernetes Kube-Proxy Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/proxy
ExecStart=/usr/bin/kube-proxy \
        $KUBE_LOGTOSTDERR \
        $KUBE_LOG_LEVEL \
        $KUBE_MASTER \
        $KUBE_PROXY_ARGS \
        --proxy-mode=userspace
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```
- 启动 kubelet 和 kube-proxy 服务：
```
$ sudo mkdir /var/lib/kubelet
$ sudo systemctl daemon-reload
$ sudo systemctl start kubelet
$ sudo systemctl start kube-proxy
$ sudo systemctl enable kubelet
$ sudo systemctl enable kube-proxy
$ kubectl config set-cluster default-cluster --server=http://10.8.217.86:8080
Cluster "default-cluster" set.
$ kubectl config set-context default-context --cluster=default-cluster --user=default-admin
Context "default-context" created.
$ kubectl config use-context default-context
Switched to context "default-context".
$ kubectl get nodes
NAME             STATUS     AGE       VERSION
svr12985hw2288   Ready      11d       v1.7.5
svr17124hp380    Ready      17m       v1.7.5
vms45200         Ready      11d       v1.7.3
vms45201         Ready      11d       v1.7.3
vms45202         Ready      11d       v1.7.3
```

### 安装 gpu driver
由于使用的 cuda 版本为8.0，下载驱动 http://www.nvidia.com/download/driverResults.aspx/115291/en-us。执行如下命令：
```
$ chmod a+x NVIDIA-Linux-x86_64-375.39.run
$ sudo ./NVIDIA-Linux-x86_64-375.39.run
Verifying archive integrity... OK
Uncompressing NVIDIA Accelerated Graphics Driver for Linux-x86_64 375.39.........................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................
$ nvidia-smi
Tue Oct 24 20:13:00 2017
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 375.39                 Driver Version: 375.39                    |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  Tesla K80           Off  | 0000:0A:00.0     Off |                    0 |
| N/A   29C    P0    58W / 149W |      0MiB / 11439MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   1  Tesla K80           Off  | 0000:0B:00.0     Off |                    0 |
| N/A   24C    P0    70W / 149W |      0MiB / 11439MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   2  Tesla K80           Off  | 0000:86:00.0     Off |                    0 |
| N/A   26C    P0    56W / 149W |      0MiB / 11439MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   3  Tesla K80           Off  | 0000:87:00.0     Off |                    0 |
| N/A   23C    P0    68W / 149W |      0MiB / 11439MiB |    100%      Default |
+-------------------------------+----------------------+----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                       GPU Memory |
|  GPU       PID  Type  Process name                               Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
```



Kubernetes 官网说 driver 需在 Kubernetes 安装后安装，目前测试下来是不需要的。
### 安装 cudnn

```
$ tar xzvf cudnn-8.0-linux-x64-v5.1.tgz
$ cd cuda
$ sudo cp include/* /usr/include
$ sudo cp lib64/* /usr/lib64
```


### 安装 nvidia-docker
- 配置 docker 代理
执行命令：`sudo mkdir /etc/systemd/system/docker.service.d`，创建文件：/etc/systemd/system/docker.service.d/http-proxy.conf，内容如下：
```
[Service]
Environment="HTTP_PROXY=xxxx" "HTTPS_PROXY=xxxx" "NO_PROXY=localhost,127.0.0.1,10.8.0.0/16"
```
执行如下命令更新配置：
```
$ sudo systemctl daemon-reload
$ sudo systemctl restart docker
```

执行如下命令：
```
$ wget -P /tmp https://github.com/NVIDIA/nvidia-docker/releases/download/v1.0.1/nvidia-docker-1.0.1-1.x86_64.rpm
$ sudo rpm -i /tmp/nvidia-docker*.rpm && rm /tmp/nvidia-docker*.rpm
$ sudo systemctl start nvidia-docker
$ sudo nvidia-docker run --rm nvidia/cuda:8.0 nvidia-smi
8.0: Pulling from nvidia/cuda
16da43b30d89: Pull complete
1840843dafed: Pull complete
91246eb75b7d: Pull complete
7faa681b41d7: Pull complete
97b84c64d426: Pull complete
ce2347c6d450: Pull complete
f7a91ae8d982: Pull complete
ac4e251ee81e: Pull complete
448244e99652: Pull complete
f69db5193016: Pull complete
Digest: sha256:a73077e90c6c605a495566549791a96a415121c683923b46f782809e3728fb73
Status: Downloaded newer image for nvidia/cuda:8.0
Tue Oct 24 11:51:07 2017
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 375.26                 Driver Version: 375.26                    |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  Tesla K80           On   | 0000:06:00.0     Off |                    0 |
| N/A   59C    P8    29W / 149W |      0MiB / 11439MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   1  Tesla K80           On   | 0000:07:00.0     Off |                    0 |
| N/A   68C    P0    81W / 149W |   9422MiB / 11439MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   2  Tesla K80           On   | 0000:83:00.0     Off |                    0 |
| N/A   39C    P8    26W / 149W |      0MiB / 11439MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   3  Tesla K80           On   | 0000:84:00.0     Off |                    0 |
| N/A   28C    P8    28W / 149W |      0MiB / 11439MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                       GPU Memory |
|  GPU       PID  Type  Process name                               Usage      |
|=============================================================================|
```


## 报错

- Error response from daemon: mkdir
``` 
$ sudo nvidia-docker run --rm nvidia/cuda:8.0 nvidia-smi
docker: Error response from daemon: mkdir /var/lib/docker/overlay/31765b1d3ce1f760c83c440ab4c122e618b1988ffb6fa40b3319971e3392be6a-init/merged/dev/shm: invalid argument.
See 'docker run --help'.
``` 

见 https://docs.docker.com/engine/userguide/storagedriver/selectadriver/#check-and-set-your-current-storage-driver


/etc/docker/daemon.json：
```
{
  "storage-driver": "devicemapper"
}
```
重启 docker 即可。
