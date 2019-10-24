# Intro

MPI 是一系列并发计算架构的消息传输接口(Message Passing Interface)标准，其只是一个接口的标准定义，程序员需要根据不同架构去实现这个接口。

## MPI 对消息传递模型的定义
MPI 在消息传递模型上的一些概念如下：
- 通讯器（communicator）    
  通讯器定义了一组能够互相发消息的进程，在这组进程中，每个进程会被分配一个序号，称作秩（rank），进程间显性的通过秩来进行通信。
- 点对点通信（point-to-point）    
  一个进程可以通过指定另一个进程的秩以及一个独一无二的消息标签来发送消息给另一个进程，接受者可以发送一个接收特定标签标记的消息的请求，然后依次处理接收到的数据。类似这样涉及一个发送者和一个接受者的通信被称作点对点通信。
- 集体性（collective）通信      
  在很多情况下，某个进程可能需要跟其他所有进程通信，比如主进程想发一个广播给所有的从进程，在这种情况下，手写一个个进程点对点的信息传递会显得很笨拙，且会导致网络利用率低下。MPI 提供了专门的接口来处理这类所有进程间的集群性通信。

## 点对点通信
若进程 A 需要发送一些消息给进程 B，进程 A 会将需要发送的所有数据打包好，放在一个缓存里面。因为所有数据会被打包到一个大的信息里面，因此缓存常常被比作信封。数据打包进缓存之后，通信设备根据进程 B 的秩把数据传递组进程 B。数据发送给进程 B 后，进程 B 仍然需要确认它是否想接受进程 A 的数据。一旦 B 确认后，数据就被传输成功了。

有时 A 需要传递很多不同消息给 B，为了区分不同的消息，MPI 运行发送者和接受者额外的指定一些信息 tag，当 B 只要求接收某种特定 tag 的信息的时候，其他不是这个 tag 的信息会先被缓存起来，等到 B 需要的时候才发送给 B。

如下是 MPI 发送方法和接收方法的定义：

```
MPI_Send(
    void* data,
    int count,
    MPI_Datatype datatype,
    int destination,
    int tag,
    MPI_Comm communicator)

MPI_Recv(
    void* data,
    int count,
    MPI_Datatype datatype,
    int source,
    int tag,
    MPI_Comm communicator,
    MPI_Status* status)
```

## 集体通信
集体通信指的是一个涉及通信器里面所有进程的一个方法。关于集体通信需记住的一点是它在进程间引入了同步点的概念，意味着所有的进程在执行代码时候必须先到达一个同步点才能执行后面的代码。MPI 有一个特殊的函数来做同步进程的这个操作：`MPI_Barrier(MPI_Comm communicator)`，这个方法会构建一个屏障（Barrier），任何进程都没法跨越屏障，直到所有的进程都到达屏障，如下示意图（水平轴代表的是程序的执行过程，小圆圈代表不同的进程）：

![barrier](barrier.png)

进程 0 在时间点 (T 1) 首先调用 MPI_Barrier。然后进程 0 就一直等在屏障之前，之后进程 1 和进程 3 在 (T 2) 时间点到达屏障。当进程 2 最终在时间点 (T 3) 到达屏障的时候，其他的进程就可以在 (T 4) 时间点再次开始运行。

`MPI_Barrier` 在很多时候很有用，比如同步一个程序，使用的分布式代码中的某一部分可以被精确的计时。关于同步有个需要注意的地方即：始终记得每一个你调用的集体通信方法都是同步的。

### 广播
广播是标准的集体通信技术之一。一个广播发生的时候，一个进程会把同样一份数据传递给一个 communicator 里面的所有其他进程。广播的主要用途之一是把用户输入传递给一个分布式程序，或者把一些配置参数传递给所有的进程。

在 MPI 中，广播可以使用 `MPI_Bcast` 来做到，函数签名看起来如下：
```
MPI_Bcast(
    void* data,
    int count,
    MPI_Datatype datatype,
    int root,
    MPI_Comm communicator)
```

### MPI_Scatter、MPI_Gather 和 MPI_Allgather
`MPI_Scatter` 是一个跟 `MPI_Bcast` 类似的集体通信机制，其将根进程的数据发送给 communicator 中所有进程，区别是 `MPI_Bcast` 给每个进程发送的是同样的数据，然而 `MPI_Scatter` 给每个进程发送的部分数据。

![bcast_vs_scatter](broadcastvsscatter.png)

`MPI_Gather` 跟 `MPI_Scatter` 作用是相反的，其从若干个进程中收集数据到一个进程上面，如下是其示意图：

![gather](gather.png)

`MPI_Scatter` 和 `MPI_Gather` 用来操作多对一或一对多的通信模式，对于多对多的通信模式，可以使用 `MPI_Allgather`。对于分发在所有进程上的一组数据来说，`MPI_Allgather` 会收集所有数据到所有进程上，即其相当于在一个 `MPI_Gather` 操作后跟一个 `MPI_Bcast` 操作，如下示意图：

![mpi_allgather](allgather.png)

### MPI_Reduce 和 MPI_Allreduce

reduce 是函数式编程中的一个基础概念，通过一个函数，其将一组数据缩减为更少一组数据，如对于数组 `[1, 2, 3, 4, 5]`，通过调用 `sum` 方法，最后结论为一个数字 15。`MPI_Reduce` 的作用即如此，其示意图如下：

![mpi_reduce](reduce.png)


类似于 `MPI_Allgather` 将数据发送给一组进程，`MPI_Allreduce` 也是将所有数据发给所有进程：

![mpi_allreduce](allreduce.png)



## 参考
- [Message Passing Interface](https://en.wikipedia.org/wiki/Message_Passing_Interface)
