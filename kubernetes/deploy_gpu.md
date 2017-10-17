# Kubernetes GPU 使用

这里以 Kubernetes 部署 TensorFlow + Jupyter 说下 GPU 的使用过程。操作系统为 CentOS 7.1。

## 过程
### 准备
- 一台 GPU 机器，测试机器为：
```
$ lspci | grep -i nvidia
06:00.0 3D controller: NVIDIA Corporation GK210GL [Tesla K80] (rev a1)
07:00.0 3D controller: NVIDIA Corporation GK210GL [Tesla K80] (rev a1)
83:00.0 3D controller: NVIDIA Corporation GK210GL [Tesla K80] (rev a1)
84:00.0 3D controller: NVIDIA Corporation GK210GL [Tesla K80] (rev a1)
```
- 已有的 Kubernetes 集群，关于 Kubernetes 集群搭建，参见前文，这里不赘述。

### 安装 CUDA 及 GPU 驱动
下载 [cuda_8.0.61_375.26_linux.run](https://developer.nvidia.com/compute/cuda/8.0/Prod2/local_installers/cuda_8.0.61_375.26_linux-run) 和 [patch](https://developer.nvidia.com/compute/cuda/8.0/Prod2/patches/2/cuda_8.0.61.2_linux-run)。执行如下命令安装：
```
$ mv cuda_8.0.61_375.26_linux-run cuda_8.0.61_375.26_linux.run 
$ chmod a+x cuda_8.0.61_375.26_linux.run
$ bash cuda_8.0.61_375.26_linux.run
$ mv cuda_8.0.61.2_linux-run cuda_8.0.61.2_linux.run
$ chmod a+x cuda_8.0.61.2_linux.run
$ bash cuda_8.0.61.2_linux.run
$ sudo mkdir /usr/lib64/nvidia
// 将 nvidia_dirver 的 lib 拷贝至 /usr/lib64/nvidia，方便后续给容器使用
$ sudo cp /var/lib/nvidia-docker/volumes/nvidia_driver/375.26/lib64/* /usr/lib64/nvidia
```
在安装过程中，选择安装驱动程序。注意，官网中有如下一段话：
> Kubernetes nodes have to be pre-installed with Nvidia drivers. Kubelet will not detect Nvidia GPUs otherwise. Try to re-install Nvidia drivers if kubelet fails to expose Nvidia GPUs as part of Node Capacity.
即 Kubernetes 需在 Nvidia 驱动安装前安装。这里我没测试 Kubernetes 在显卡驱动后安装的情况。

如果 cuda 已安装，但驱动未安装，可从官网下载驱动单独安装。在 [驱动程序下载](http://www.nvidia.cn/Download/index.aspx?lang=cn) 中选择对应的驱动类型，下载后执行命令：
```
$ rpm -i nvidia-diag-driver-local-repo-rhel7-384.66-1.0-1.x86_64.rpm
$ yum clean all
$ yum install cuda-drivers
// 安装后重启机器
$ reboot
$ cat /proc/driver/nvidia/version
NVRM version: NVIDIA UNIX x86_64 Kernel Module  384.66  Sat Sep  2 02:43:11 PDT 2017
GCC version:  gcc version 4.8.3 20140911 (Red Hat 4.8.3-9) (GCC)
$ nvidia-smi
```
对于 Tensorflow 而言，可能还需要安装 cuDNN，不过这里为讲解 Kubernetes 管理 GPU，因此跳过这部分。

### 安装 nvidia-docker
若 docker 不通访问外网，先修改 `/etc/systemd/system/docker.service.d/http-proxy.conf` 设置代理：
```
# /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=http://X:PORT/" "HTTPS_PROXY=http://X:PORT/" "NO_PROXY=localhost,127.0.0.1,10.8.0.0/16"
```
保存后重启 docker：
```
$ sudo systemctl daemon-reload
$ sudo systemctl restart docker
```

接着安装 nvidia-docker，如下：
```
$ Install nvidia-docker and nvidia-docker-plugin
$ wget -P /tmp https://github.com/NVIDIA/nvidia-docker/releases/download/v1.0.1/nvidia-docker-1.0.1-1.x86_64.rpm
$ sudo rpm -i /tmp/nvidia-docker*.rpm && rm /tmp/nvidia-docker*.rpm
$ sudo systemctl start nvidia-docker
// Test nvidia-smi
$ sudo nvidia-docker run --rm nvidia/cuda nvidia-smi
```

### 修改 kubernetes 配置

kubelet 启动命令中添加 `--feature-gates="Accelerators=true"` 用于支持 GPU，本测试环境由于 kubelet 启动命令时带有 KUBELET_ARGS，因此在 /etc/kubernetes/kubelet 中添加行：`KUBELET_ARGS='--feature-gates="Accelerators=true"'`，重启 kubelet 服务。

### 编写 GPU yml 文件，启动 gpu 容量
文件 tf_gpu.yml 内容如下：
```
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: tf-gpu
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: tf-gpu
    spec:
      volumes:
      - hostPath:
          path: /usr/bin
        name: bin
      - hostPath:
          path: /usr/lib64/nvidia
        name: lib
      containers:
      - name: tensorflow
        image: tensorflow/tensorflow:latest-gpu
        ports:
        - containerPort: 8888
        resources:
          limits:
            alpha.kubernetes.io/nvidia-gpu: 1
        volumeMounts:
        - mountPath: /usr/local/nvidia/bin
          name: bin
        - mountPath: /usr/local/nvidia/lib
          name: lib
---
apiVersion: v1
kind: Service
metadata:
  name: tf-gpu-service
  labels:
    app: tf-gpu
spec:
  selector:
    app: tf-gpu
  ports:
  - port: 8888
    protocol: TCP
    nodePort: 30061
  type: LoadBalancer
```
执行命令 `kubectl create -f tf_gpu.yml`，创建 service 和 deployment，查看容器宿主机 IP 和端口，访问该 tensorflow jupyter 服务，在 jupyter 中打开一个服务，输入如下程序校验：
```
from tensorflow.python.client import device_lib

def get_available_devices():
    local_device_protos = device_lib.list_local_devices()
    return [x.name for x in local_device_protos]

print(get_available_devices())
[u'/cpu:0', u'/gpu:0', u'/gpu:1', u'/gpu:2', u'/gpu:3']
```

注意: tensorflow 镜像不要使用 tag 为 devel-gpu ，可能出现启动不了的情况。

## 报错

### Error: unsupported CUDA version: driver 7.5 < image 8.0.61
执行命令：`sudo nvidia-docker run -p 8888:8888 -d --name tf-jupyter tensorflow/tensorflow:1.3.0-devel-gpu` 时，报错：`nvidia-docker | 2017/09/27 19:42:59 Error: unsupported CUDA version: driver 7.5 < image 8.0.61`。看报错应该是 tensorflow 使用的cuba版本与驱动不兼容，升级驱动。本机使用的 cuba 版本为 7.5，驱动为 352.99。
在 [驱动程序下载](http://www.nvidia.cn/Download/index.aspx?lang=cn) 中选择对应的驱动类型，下载安装即可。

## 参考
- [Schedule GPUs](https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/)

