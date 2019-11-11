# Intro

NCCL (Nvidia Collective Communications Library) 实现了 multi-GPU 和 multi-node 间的集体性通信原语，并为 Nividia GPU 提供了性能优化。NCCL 提供了诸如 all-gather, all-reduce, broadcast, reduce, reduce-scatter 等程序（routine），这些程序经过优化用以实现 PCIe 和 NVLink 高速互连上的高带宽。深度学习的开发人员可以依靠 NCCL 的高度优化，MPI 兼容和拓扑感知程序（routine）来充分利用多个节点内和跨多个节点间的所有可用 GPU，譬如 Caffe，MxNet，TensorFlow 和 PyTorch 等已经集成了 NCCL 用以加速在多 GPU 系统上的深度学习训练。

NCCL 有如下特性：   
- 支持多线程和多进程应用
- 通过聚合 GPU 间 reduce 操作，来加快训练更新和更深的模型
- 多个 ring 网以提高总线利用率
- 大规模多 GPU 和多节点训练的树算法实现以减少延迟
- 支持 InfiniBand Verbs，libfabric，RoCE 和IP Socket 节点间通信

NCCL 使用 C API，能方便的被其他编程语言调用。MPI 严格遵循 MPI 定义的集体性通信的 API，任何熟悉 MPI 的人都能轻松的使用 NCCL。在深度学习框架中，NCCL 的 AllReduce 方法被广泛用于神经网络训练中。

## 使用 NCCL
使用 NCCL 和使用其他库类似：   
1. 在系统中安装 NCCL 库
2. 修改应用使用 NCCL 库
3. 在应用中添加 nccl.h 头文件
4. 创建通信器（communicator）
5. 使用 NCCL 集体性通信原语来交互数据，可通过 [NCCL API](https://docs.nvidia.com/deeplearning/sdk/nccl-developer-guide/docs/api.html#api-label) 来最大化优化性能。

### 创建通信器
通信器组中的每个 CUDA 设备通过从 0 开始的索引（index）或秩(rank) 进行标识，每个秩使用一个通信器对象来引用一组 GPU 集合。不支持地同一 NCCL 通信器中同一 CUDA 设备使用多次时使用的是不同的秩。

对于给定的 CUDA 设备，首先通过调用 [ncclGetUniqueId()](https://docs.nvidia.com/deeplearning/sdk/nccl-developer-guide/docs/api/comms.html#c.ncclGetUniqueId) 来创建一个唯一对象，所有进程和线程都将使用将对象来同步并理解它们是同一通信器中的一部分。接着调用 [ncclCommInitRank](https://docs.nvidia.com/deeplearning/sdk/nccl-developer-guide/docs/api/comms.html#c.ncclCommInitRank) 和 [ncclCommInitAll](https://docs.nvidia.com/deeplearning/sdk/nccl-developer-guide/docs/api/comms.html#c.ncclCommInitAll) 来创建通信器对象，每个通信器对象被分配一个固定的秩，这些对象将用于启动通信操作。

在使用多个NCCL 通信器时需要注意同步：NCCL 内核处于阻塞状态中，其等待数据到达，任何 CUDA 操作都可能引起设备同步，这意味着它会等待所有 NCCL 内核完成操作，而由于 NCCL 操作又会引用 CUDA 调用，此时可能会导致死锁。因此，应在不同时期使用带锁机制的位于不同通信器上的操作，且应用程序应确保在各个秩之间以相同顺序提交操作。

### 操作
如同 MPI 集体操作一样， NCCL 集体操作须在每个秩调用以形成完整的集合操作。

#### AllReduce
AllReduce 操作对设备上的数据进行 Reduce 操作（如求合，最大值等）并将结果写到每个秩的接收缓冲区中。如下图：

![allreduce](img/allreduce.png)

> All-Reduce operation: each rank receives the reduction of input values across ranks.

#### Broadcast
Broadcast 操作将 root 秩上 N元素的 buffer 拷贝到所有秩上。

![broadcast](img/broadcast.png)

> Broadcast operation: all ranks receive data from a “root” rank.

#### Reduce
Reduce 操作和 AllReduce 操作类似，但只将结果输出到指定的 root 秩中。

![reduce](img/reduce.png)

> Reduce operation : one rank receives the reduction of input values across ranks.

Reduce 操作后跟一个 Broadcast 操作，等同于一个 AllReduce 操作。

#### AllGather
对于 AllGather 操作而言，K 个处理器乘以每个处理器中的 N 个值组成一个 K*N 大小的输出，输出通过秩的索引排序。

![allgather](img/allgather.png)

> AllGather operation: each rank receives the aggregation of data from all ranks in the order of the ranks.

#### ReduceScatter

ReduceScatter 操作同 Reduce 操作类似，不同之处在于结果分散在各个秩之间相等的块中，每个秩基于其索引获得对应的一部分数据。

![reducescatter](img/reducescatter.png)

> Reduce-Scatter operation: input values are reduced across ranks, with each rank receiving a subpart of the result.

### 数据指针
通常 NCCL 将接收任何与通信器对象关联且可访问的 CUDA 设备的 CUDA 指针，包括：
- CUDA 设备本地的设备内存
- 使用 CUDA SDK API cudaHostRegister 或 cudaGetDevicePointer 注册的机器内存
- 托管和统一的内存

唯一的例外是设备内存位于另一台设备上，但可以通过对待访问从当前设备访问。在这种情况下，NCCL 将返回错误以避免程序错误。

### CUDA 流式语法

CUDA 调用与流关联，并能作为集体通信功能的最后一个参数传递。操作传递给指定流后，要么返回 NCCL 调用，要么返回错误，然后在 CUDA 设备上异步执行集体通信操作。

### 组调用(group calls)
#### 一个进程管理多个 GPU
当一个进程管理多个设备时，必须使用组语法，这是因为每个 NCCL 调用都可能在发送 NCCL 操作给指定流前阻塞，以等待其他进程/秩到来。如下：
```
for (int i=0; i<nLocalDevs; i++) {
  ncclAllReduce(..., comm[i], stream[i]);
}
```

为了定义这些调用是同一集体通信的一部分， 必须使用 `ncclGroupStart` 和 `ncclGroupEnd`，以告诉 NCCL 将所有处于 `ncclGroupStart` 和 `ncclGroupEnd` 之间的调用当作一个调用对待：
```
ncclGroupStart();
for (int i=0; i<nLocalDevs; i++) {
  ncclAllReduce(..., comm[i], stream[i]);
}
ncclGroupEnd();
```

#### 聚合操作   
组语法还可以用于在单个 NCCL 启动中执行多个集体操作，这对于减少启动延迟很有用。可以通过在 `ncclGroupStart` 和 `ncclGroupEnd` 中多次调用 NCCL 来完成聚合的集体通信操作。如下，通过一次 NCCL 启动来完成一个广播和二个 allReduce 操作：
```
ncclGroupStart();
ncclBroadcast(sendbuff1, recvbuff1, count1, datatype, root, comm, stream);
ncclAllReduce(sendbuff2, recvbuff2, count2, datatype, comm, stream);
ncclAllReduce(sendbuff3, recvbuff3, count3, datatype, comm, stream);
ncclGroupEnd();
```
需要注意的是，对于给定的 NCCL 通信器，不能使用不同的流，如下操作会返回错误：
```
ncclGroupStart();
ncclAllReduce(sendbuff1, recvbuff1, count1, comm, stream1);
ncclAllReduce(sendbuff2, recvbuff2, count2, comm, stream2);
ncclGroupEnd();
```

### 线程安全
NCCL 原语通常不是线程安全的，但它们是可重入的。多个线程应使用单独的通信器对象。

### In-place 操作
与 MPI 不同的是，NCCL 没有提供一个特殊的 "in-place" 值来代替指针，相反，NCCL 会优化提供的 "in-place" 指针的这种情况。

对于 ncclBroadcast, ncclReduce 和 ncclAllreduce 函数而言，意味着传递 `sendBuff == recvBuff` 会执行 "in-place" 操作，将最终结果存储在读取初始数据的位置。对于 ncclReduceScatter 和 ncclAllGather 而言，当每行指针位于全局缓冲区的行偏移量时，将执行 "in-place" 操作，更准确的说，这些调用被认为是适当的：
```
ncclReduceScatter(data, data+rank*recvcount, recvcount, datatype, op, comm, stream);
ncclAllGather(data+rank*sendcount, data, sendcount, datatype, op, comm, stream);
```

### NCCL 和 MPI
尽管 NCCL API 和 MPI 相似，但两者仍然有不少细微的不同，如下：

- 每个进程使用多个设备       
与 MPI endpoints 的概念类似，NCCL 不需要将秩 1:1 的映射到 MPI 秩。NCCL 通信器可能具有单个进程关联的许多秩。

- ReduceScatter 操作  
ReduceScatter 操作类似于 MPI_Reduce_scatter_block 操作，而不是 MPI_Reduce_scatter 操作。MPI_Reduce_scatter 函数本质上是一个“向量函数”，而 MPI_Reduce_scatter_block 提供的常规计数类似于镜像函数 MPI_Allgather，由于这是 MPI 的一个古怪的地方，NCCL 并未遵循。

- 发送和接收计数(counts)    
在许多集体操作中，只要 sendcount * sizeof (sendtype) == recvcount * sizeof (recvtype)，MPI就允许不同的发送和接收计数和类型，但 NCCL 不允许这样做，因为它定义了一个计数和一个数据类型。
对于 AllGather 和 ReduceScatter 操作而言，该计数等于每行大小，即最小大小；另一个计数等 nranks * count。函数原型清楚的显示了提供的计数。

- In-place 操作   
见上文。

## 参考
- [NVIDIA Collective Communications Library](https://developer.nvidia.com/nccl)
- [NCCL: ACCELERATED MULTI-GPU COLLECTIVE COMMUNICATIONS](https://images.nvidia.com/events/sc15/pdfs/NCCL-Woolley.pdf)
- [nccl docs](https://docs.nvidia.com/deeplearning/sdk/nccl-developer-guide/docs/index.html)
- [Massively Scale Your Deep Learning Training with NCCL 2.4](https://devblogs.nvidia.com/massively-scale-deep-learning-training-nccl-2-4/)
