# HDFS Recovery Processes

## Lease Recovery
### Lease Manager
HDFS不支持并发写，其用lease保证唯一写。lease相当于一把带时间限制的写锁，其由NameNode中的lease manager管理，每个namespace都有各自对应的lease manager。lease有两种有效期：soft limit（有效期1分钟）和hard limit（有效期1小时）。lease拥有者在soft limit时间内对文件有唯一写锁，如果该客户端需要一直写，其会启动后台线程不断的续借(renew)lease。在超过soft limit而未达到hard limit时间内，其他客户端可接管该lease。

lease manager支持如下操作：
- 给客户端和文件添加/删除lease。
- 检查lease是否达到soft/hard limit限制。
- 为客户端续借lease。

lease manager每隔2s会启动一个监控线程检查是否有lease达到hard limit限制，如果达到的话，其会触发lease recovery进程回收这些lease。


### Lease Recovery

lease会在如下情况下释放：
- 客户端显式请求NameNode对某个文件进行recoverLease操作。或通过shell命令显示调用：`hdfs debug recoverLease [-path <path>] [-retries <num-retries>]`。
- lease超过soft limit限制而客户端又未续借lease，此时另一客户端可强制接管该lease。
- lease超过hard limit限制而客户端又未续借lease，Namenode将自动关闭文件并释放lease。
- 正常关闭文件时，lease也会释放。

释放lease会引起DataNode对block的recovery过程，当DataNode完成recover block过程后，文件会被关闭。

参见[Lease Recovery Algorithm](https://github.com/apache/hadoop/blob/branch-2.6.0/hadoop-hdfs-project/hadoop-hdfs/src/main/java/org/apache/hadoop/hdfs/server/namenode/LeaseManager.java#L45)，如下：
> Lease Recovery Algorithm
1) Namenode retrieves lease information
2) For each file f in the lease, consider the last block b of f
2.1) Get the datanodes which contains b
2.2) Assign one of the datanodes as the primary datanode p
2.3) p obtains a new generation stamp from the namenode
2.4) p gets the block info from each datanode
2.5) p computes the minimum block length
2.6) p updates the datanodes, which have a valid generation stamp,
>     with the new generation stamp and the minimum block length 
2.7) p acknowledges the namenode the update results
2.8) Namenode updates the BlockInfo
2.9) Namenode removes f from the lease
>     and removes the lease once all files have been removed
2.10) Namenode commit changes to edit log

## 参考
- [Understanding HDFS Recovery Processes (Part 1)](http://blog.cloudera.com/blog/2015/02/understanding-hdfs-recovery-processes-part-1/)
- [Understanding HDFS Recovery Processes (Part 2)](https://blog.cloudera.com/blog/2015/03/understanding-hdfs-recovery-processes-part-2/)
