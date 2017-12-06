# CentOS 7 上安装 Caffe

安装 caffe 说麻烦也麻烦，主要是各种依赖的问题，由于 tensorflow 镜像问题，需要升级 GPU 驱动，升级后当然会升级 cuda 等，这却对原本正常的 caffe 产生了影响，导致 caffe 使用异常，需要再重新安装 caffe，由于重装与初次安装过程类似，这里记录下过程。本文基于这个背景产生。


## 前面的折腾
新安装的 cuda 版本为 9.0，cuDNN 为 v7.0.3，重装的 caffe 版本为 caffe 1.0.0-rc3 ，结果一直报错：`.build_release/lib/libcaffe.so: undefined reference to `google::ParseCommandLineFlags(int*, char***, bool)`。之前正常运行的 cuda 版本为 7.5，所以初步怀疑是新版本 cuda/cuDNN 与 caffe 不兼容造成的问题。而 tensorflow docker 镜像默认版本为 8.0。所以这里先确定好 cuda 和 cuDNN 版本。

查看 [caffe 文档](http://caffe.berkeleyvision.org/installation.html)，如下：
>- CUDA is required for GPU mode.
>   - library version 7+ and the latest driver version are recommended, but 6.* is fine too
>   - 5.5, and 5.0 are compatible but considered legacy
>- cuDNN Caffe: for fastest operation Caffe is accelerated by drop-in integration of NVIDIA cuDNN. To speed up your Caffe models, install cuDNN then uncomment the USE_CUDNN := 1 flag in Makefile.config when installing Caffe. Acceleration is automatic. The current version is cuDNN v6; older versions are supported in older Caffe.
>

cuda 版本支持 7.0 以上，cuDNN 目前只支持到 v6，故 cuDNN v7.0.3 目前暂不支持，替换为安装 cuda 8.0，cuDNN v5.1（v5.1 和 v6.0 均可，这里由于caffe 版本略老，之前安装 cuDNN 版本为 v5.1，故本次安装也选择 v5.1，v6 的安装过程应该大致相同），重新安装。

## 安装过程

### 安装 cuda 8 & patch
下载 [cuda8](https://developer.nvidia.com/compute/cuda/8.0/Prod2/local_installers/cuda_8.0.61_375.26_linux-run) 及 [patch](https://developer.nvidia.com/compute/cuda/8.0/Prod2/patches/2/cuda_8.0.61.2_linux-run)，修改后缀，将 linux-run 变更为 linux.run，执行命令`bash cuda_8.0.61_375.26_linux.run` 安装，patch同理。cuda 8 会有提示安装驱动的步骤，当然也可通过 [驱动程序下载](http://www.nvidia.cn/download/driverResults.aspx/123014/cn) 下载。若需要替换 cuda 版本，若 nvidia-docker 已启动，先将其停掉：`sudo systemctl stop nvidia-docker.service`。安装后验验：
```
$ nvidia-smi
Sat Sep 30 11:09:10 2017
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 375.26                 Driver Version: 375.26                    |
|-------------------------------+----------------------+----------------------+
```

### 安装 cuDNN 
由于需要安装的 caffe 版本为 1.0.0-rc3，这里下载 [cuDNN v5.1](https://developer.nvidia.com/rdp/cudnn-download)，cuDNN 的下载需要注册。安装：
```
$ tar xzvf cudnn-8.0-linux-x64-v5.1.tgz
$ sudo cp cuda/include/* /usr/local/cuda/include
$ sudo cp cuda/lib64/* /usr/local/cuda/lib64
```

### 安装 BLAS
这里安装 ATLAS:
```
sudo yum install atlas-devel
cd  /usr/lib64/atlas 
sudo ln -sv libsatlas.so.3.10 libcblas.so
sudo ln -sv libsatlas.so.3.10 libatlas.so
```

### 重装低于 1.54 的 boost 
若 boost 版本低于 1.54，则需要重装boost，过程如下：
```
# yum remove boost-devel
# wget https://netix.dl.sourceforge.net/project/boost/boost/1.55.0/boost_1_55_0.tar.gz
# tar xvzf boost_1_55_0.tar.gz
# cd boost_1_55_0
# ./bootstrap.sh
# ./b2
# ./b2 install -j28  threading=multi --layout=tagged  --prefix=/opt/boost
# cd /opt/boost
# cp -r include/ /usr/include
# cp lib/* /usr/lib64
```

### 安装 caffe
- 参考 [Prerequisites](http://caffe.berkeleyvision.org/installation.html#prerequisites)，安装依赖：`sudo yum install protobuf-devel glog-devel gflags-devel hdf5-devel lmdb-devel leveldb-devel snappy-devel opencv-devel boost-devel openblas-devel`。
- 接着下载 caffe: `git clone https://github.com/BVLC/caffe.git`，进入 caffe/python 目录，安装 Python 依赖：`for r in $(cat requirements.txt); do pip install $r; done`.
- 生成 Makefile.config 文件：`cp Makefile.config.example Makefile.config`，并做如下修改：
```
USE_CUDNN := 1
BLAS := atlas
BLAS_INCLUDE := /usr/include/atlas
BLAS_LIB := /usr/lib64/atlas
PYTHON_INCLUDE := /usr/include/python2.7 \
                /usr/lib64/python2.7/site-packages/numpy/core/include
PYTHON_LIB := /usr/lib64
```
- 编译安装：
```
mkdir build
cd build 
cmake ..
make all -j32
make pycaffe
make install
```

修改 `/etc/bashrc`，添加如下行：
```
export PATH=$PATH:$CUDA_HOME/bin:/opt/caffe/build/tools
export PYTHONPATH=$PYTHONPATH:/opt/caffe/python
```

若 cmake 时报错：
```
.build_release/lib/libcaffe.so: undefined reference to `google::ParseCommandLineFlags(int*, char***, bool)'
collect2: error: ld returned 1 exit status
.build_release/lib/libcaffe.so: undefined reference to `google::ParseCommandLineFlags(int*, char***, bool)'
collect2: error: ld returned 1 exit status
make: *** [.build_release/tools/upgrade_solver_proto_text.bin] Error 1
make: *** Waiting for unfinished jobs....
make: *** [.build_release/tools/upgrade_net_proto_text.bin] Error 1
.build_release/lib/libcaffe.so: undefined reference to `google::ParseCommandLineFlags(int*, char***, bool)'
collect2: error: ld returned 1 exit status
make: *** [.build_release/tools/train_net.bin] Error 1
```
可将命令修改为：`cmake -D GFLAGS_LIBRARY=/usr/local/lib/libgflags.a  ..`。

若报错：
```
-- OpenCV found (/usr/lib64/cmake/OpenCV)
CMake Error at /usr/share/cmake/Modules/FindPackageHandleStandardArgs.cmake:108 (message):
  Could NOT find Atlas (missing: Atlas_CBLAS_LIBRARY Atlas_BLAS_LIBRARY
  Atlas_LAPACK_LIBRARY)
Call Stack (most recent call first):
  /usr/share/cmake/Modules/FindPackageHandleStandardArgs.cmake:315 (_FPHSA_FAILURE_MESSAGE)
  cmake/Modules/FindAtlas.cmake:43 (find_package_handle_standard_args)
  cmake/Dependencies.cmake:113 (find_package)
  CMakeLists.txt:46 (include)
```
执行：`cmake -DBLAS=open .. `。


安装完成后，在 `build/tools` 中可找到 caffe 相关可执行文件，在 python 中，caffe 模块也已安装。至此安装完成。

