# CentOS7.3 安装 tensorflow

在腾讯云上申请了一台腾讯云的 GPU 机器准备做机器学习使用，下面是安装 TensorFlow 的过程：

## 安装 
### 安装 nvidia 驱动
执行如下命令：
```
$ wget http://cn.download.nvidia.com/tesla/384.66/nvidia-diag-driver-local-repo-rhel7-384.66-1.0-1.x86_64.rpm
$ sudo rpm -i nvidia-diag-driver-local-repo-rhel7-384.66-1.0-1.x86_64.rpm
$ sudo yum -y install cuda-drivers
$ reboot
```

### 安装 cuda8
执行如下命令：
```
$ wget https://developer.nvidia.com/compute/cuda/8.0/prod/local_installers/cuda-repo-rhel7-8-0-local-8.0.44-1.x86_64-rpm
$ mv cuda-repo-rhel7-8-0-local-8.0.44-1.x86_64-rpm cuda-repo-rhel7-8-0-local-8.0.44-1.x86_64.rpm
$ sudo rpm -i cuda-repo-rhel7-8-0-local-8.0.44-1.x86_64.rpm
$ sudo yum -y install cuda
```

在 `/usr/local/cuda/extras` 目录下，可以看到 CUPTI 目录，即 CentOS 系统上安装 cuda 时自动会安装 CUPTI。

修改 /etc/bashrc，添加如下行：
```
export CUDA_HOME=/usr/local/cuda
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$CUDA_HOME/lib64
export PATH=$PATH:$CUDA_HOME/bin
```

### 安装 cudnn
在安装 cudnn 前，注意对应 Tensorflow/Caffe 依赖的 cudnn 版本，如 Tensorflow 1.3 之后版本需安装 cudnn6，1.2.x 需安装 cudnn 5.1。这里安装 Tensorflow 1.4，所以对应安装 cudnn6。cudnn 的下载需注册。
```
// 下载需注册，这里建议从其他机器拷贝过来
$ wget https://developer.nvidia.com/compute/machine-learning/cudnn/secure/v6/prod/8.0_20170307/cudnn-8.0-linux-x64-v6.0-tgz
$ mv cudnn-8.0-linux-x64-v6.0-tgz cudnn-8.0-linux-x64-v6.0.tgz
$ tar xzvf cudnn-8.0-linux-x64-v6.0.tgz
$ sudo cp cuda/include/* /usr/local/cuda/include
$ sudo cp cuda/lib64/* /usr/local/cuda/lib64
```

### 安装 python-dev
python:
```
yum -y install python-pip python-devel # for Python 2.7
yum -y install python3-pip python3-devel # for Python 3.n
```

### 安装 tensorflow：
```
# 使用豆瓣 pip 源
pip install -i http://pypi.doubanio.com/simple --trusted-host=pypi.doubanio.com tensorflow-gpu
```

### 简单测试：
```
# python
Python 2.7.5 (default, Nov  6 2016, 00:28:07)
[GCC 4.8.5 20150623 (Red Hat 4.8.5-11)] on linux2
Type "help", "copyright", "credits" or "license" for more information.
>>> import tensorflow as tf
>>> print(tf.__version__)
1.4.0
>>> hello = tf.constant('Hello, TensorFlow!')
>>> sess = tf.Session()
2017-11-13 15:38:04.121797: I tensorflow/stream_executor/cuda/cuda_gpu_executor.cc:892] successful NUMA node read from SysFS had negative value (-1), but there must be at least one NUMA node, so returning NUMA node zero
2017-11-13 15:38:04.122268: I tensorflow/core/common_runtime/gpu/gpu_device.cc:1030] Found device 0 with properties:
name: Tesla M40 24GB major: 5 minor: 2 memoryClockRate(GHz): 1.112
pciBusID: 0000:00:06.0
totalMemory: 22.40GiB freeMemory: 22.29GiB
2017-11-13 15:38:04.122293: I tensorflow/core/common_runtime/gpu/gpu_device.cc:1120] Creating TensorFlow device (/device:GPU:0) -> (device: 0, name: Tesla M40 24GB, pci bus id: 0000:00:06.0, compute capability: 5.2)
>>> print(sess.run(hello))
Hello, TensorFlow!
```

### mnist 测试
拷贝代码 [mnist_softmax.py](https://github.com/tensorflow/tensorflow/blob/r1.4/tensorflow/examples/tutorials/mnist/mnist_softmax.py)，然后执行：
```
# python mnist_softmax.py
Successfully downloaded train-images-idx3-ubyte.gz 9912422 bytes.
Extracting /tmp/tensorflow/mnist/input_data/train-images-idx3-ubyte.gz
Successfully downloaded train-labels-idx1-ubyte.gz 28881 bytes.
Extracting /tmp/tensorflow/mnist/input_data/train-labels-idx1-ubyte.gz
Successfully downloaded t10k-images-idx3-ubyte.gz 1648877 bytes.
Extracting /tmp/tensorflow/mnist/input_data/t10k-images-idx3-ubyte.gz
Successfully downloaded t10k-labels-idx1-ubyte.gz 4542 bytes.
Extracting /tmp/tensorflow/mnist/input_data/t10k-labels-idx1-ubyte.gz
2017-11-13 16:02:31.301970: I tensorflow/stream_executor/cuda/cuda_gpu_executor.cc:892] successful NUMA node read from SysFS had negative value (-1), but there must be at least one NUMA node, so returning NUMA node zero
2017-11-13 16:02:31.302445: I tensorflow/core/common_runtime/gpu/gpu_device.cc:1030] Found device 0 with properties:
name: Tesla M40 24GB major: 5 minor: 2 memoryClockRate(GHz): 1.112
pciBusID: 0000:00:06.0
totalMemory: 22.40GiB freeMemory: 22.29GiB
2017-11-13 16:02:31.302517: I tensorflow/core/common_runtime/gpu/gpu_device.cc:1120] Creating TensorFlow device (/device:GPU:0) -> (device: 0, name: Tesla M40 24GB, pci bus id: 0000:00:06.0, compute capability: 5.2)
0.918
```
若数据集下载的太慢，可自动从 [THE MNIST DATABASE](http://yann.lecun.com/exdb/mnist/) 下载，放置于`/tmp/tensorflow/mnist/input_data`下。

## 参考
- [Installing TensorFlow from Sources](https://www.tensorflow.org/install/install_sources?hl=zh-cn)
