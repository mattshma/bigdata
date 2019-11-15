# 制作 GPU 镜像须知
如下几个包需安装：
- [cudnn](https://developer.nvidia.com/cudnn)
- [nccl](https://github.com/NVIDIA/nccl)
- [cuBLAS](https://developer.nvidia.com/cublas)

官方 dockerfile 中已经安装了如上几个包了

CUDA_HOME 需设置。
