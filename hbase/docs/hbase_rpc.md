# HBase	RPC 分析

HBase RPC 的实现基于 Hadoop RPC，都是基于 Protobuf 和 NIO 这两个组件。HMaster, RegionServer, Client 间通信使用不同的 RPC 接口，这里先简单分析下 HMaster 与 Client 之间的 RPC 通信实现。

HMaster 端通过 RpcServer 构建 ServerSocket，Client 端使用 RpcClient 构建与服务端通信的 Socket。

## RpcServer 



在 RpcServer [start()](https://github.com/apache/hbase/blob/branch-1.2/hbase-server/src/main/java/org/apache/hadoop/hbase/ipc/RpcServer.java#L2128) 方法中，可以看到 RpcServer 主要启动 Listener, Scheduler, Responder 3 个组件，各组件功能如下：

- Listener 负责监听客户端请求。Listener 的 Executor 中有固定数量的 Reader，默认为 10。
- Scheduler
- Responder


### Linstener
[Listener](https://github.com/apache/hbase/blob/branch-1.2/hbase-server/src/main/java/org/apache/hadoop/hbase/ipc/RpcServer.java#L562) 主要封装了一个 ServerSocketChannel 和多个 Reader 线程，同时其还会清理空闲连接。ServerSocket 主要监听客户端请求，对于来不及处理的请求会先暂存于等待队列中，等待队列长度由 `hbase.ipc.server.listen.queue.size` 设置，默认为 128；对于监听到的 Client 的连接，Listener 默认开启 10 个 Reader 线程以[轮转](https://github.com/apache/hbase/blob/branch-1.2/hbase-server/src/main/java/org/apache/hadoop/hbase/ipc/RpcServer.java#L902)的方式处理 Client 端的请求，Reader 个数由参数 `hbase.ipc.server.read.threadpool.size` 设置，每个 Reader 对象都有一个 Selector，处理 Client 请求时，将拿到相应的 channel 对象并将该对象封装成 Connection 对象再加入到 ConnectionList 中，使用变量 numConnections 标记 Connection 数。Reader 对象中 doRead 方法再调用 [readAndProcess](https://github.com/apache/hbase/blob/branch-1.2/hbase-server/src/main/java/org/apache/hadoop/hbase/ipc/RpcServer.java#L1554) 方法读取 Connection 对象中的数据。对于新建的 Connection 对象，Reader 会再调用 [readPreamble](https://github.com/apache/hbase/blob/branch-1.2/hbase-server/src/main/java/org/apache/hadoop/hbase/ipc/RpcServer.java#L1482) 方法读取 Connection 对象的 RPC_HEADER，若开头为 `HBas`，则读取接下来的 2 个字节，分别为 verstion 和 auth 方法，否则读取开始读取数据。


```
|-----------------------------------------------
|  `HBas`       | <version>     | <auth_type>  |
|  4 bytes      |   1 byte      |   1 byte     |  
```



## Pluggable RpcServer
参考 [HBASE-15756](https://issues.apache.org/jira/browse/HBASE-15756)

## 参考
- [RPC通信功能实现](http://blog.csdn.net/JavaMan_chen/article/details/47039517)
- [Protocol Buffers in HBase](http://blog.zahoor.in/2012/08/protocol-buffers-in-hbase/)
