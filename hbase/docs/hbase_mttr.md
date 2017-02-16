# HBase MTTR
HBase 通过每个值只出现在一个 Region，同一时间每个 Region 只被分配给一个 RegionServer 来保证一致性。如果 RegionServer 实例挂掉或者服务器宕机，怎样尽量检查异常并恢复对 Offline Region 的访问，是 MTTR (MEAN TIME TO RECOVERY) 需要考虑的事。

众所周知，HBase 将数据保存在 HFile 中，而 HFile 存储在 HDFS 上，默认会被复制 2 份，即备份数为3。另外 HBase 使用的 WAL 也存储在 HDFS 中，备份数也为3。所以即使两台机器宕机，HBase也能恢复Region。

## HBase错误检测和恢复
HBase错误检测和恢复过程如下：

- 检测节点失败。        
  节点可能因为压力过大或者机器宕机而停止响应。
- 恢复正在进行的写操作。          
  通过读取 WAL 和恢复还未 flush 的 edits 进行恢复。
- 重新分配 Regions。         
  根据各存活的 RegionServer 的压力随机分配 Regions。

以上过程中，在检测和恢复动作发生之前，客户端因 RegionServer 宕掉一直处于阻塞状态。怎样减少客户端对数据停机的感知时间，即怎样缩减检测节点失败和恢复 Region 的时间，是 MTTR 需要做的。

### 检测节点失败
RegionServer失败的原因有好几种，第一种情况是服务被正常关闭，如服务被管理员关闭。对于这种情况，RegionServer 关闭 Region 后会通知 HMaster 其正在关闭，清除 WAL，接着 HMaster 立即分配 Region。第二种情况是网络异常或服务器异常等异常情况。对于这种情况， RegionServer 无法给 HMaster 发送信息，由于每个 RegionServer 都连接 Zookeeper 保持心跳信息，所以这种情况下如果 HMatser 监测某 RegionServer 的心跳 timeout，HMaster 将会宣布其死亡，然后开启恢复进程。

### 恢复正在进行的写操作  
由于每个 RegionServer 共用一个 WAL 文件，而 WAL 中包括各个 Region 相关的文件，所在在恢复时，WAL 需按 Region 进行切分，异常 RegionServer 上的 Region 被分配到随机的 RegionServer 上，这些 RegionServer 读取切分后的 WAL 进行恢复。上面说过，WAL 在 HDFS 也保存了 3 份。所以在读取 WAL 进行恢复的过程中，WAL 的 block 有 33% 的机率会被指向异常 RegionServer 所在的 DataNode。这就说如果异常 RegionServer 所在机器的 DataNode 能正常访问，则立即进行恢复。若异常 RegionServer 所在机器的 DataNode 不能访问，此时只能等待请求返回 timeout 后，去尝试请求另一个 DataNode 的 block。这种情况延长了恢复时间。

### 重新分配 Regions
一旦完成恢复写操作后，重新分配 Region 会很快执行，该操作依赖 Zookeeper，参见[HBASE-7247](https://issues.apache.org/jira/browse/HBASE-7247)。更多 Assignment 过程可参考[HBASE-7327](https://issues.apache.org/jira/browse/HBASE-7327)。

## MTTR 调优分析
从以上分析可以看出，若 RegionServer 被正常关闭，Region 的恢复相当快速。但若 RegionServer 因网络异常或机器宕机等意外情况无法访问，在检测阶段和恢复阶段，将花费大量时间在请求等待 timeout 上，因此优化的思路也很明确 -- 尽量减少检测和恢复的 timeout 时间。

对于检测失败节点，timeout 时间由 `zookeeper.session.timeout` 设置，默认值为 90s。为减少检测失败节点时间，可适当降低该值，不过由于 RegionServer GC 也会导致无法向 Zookeeper 发送心跳，因此该值需大于 RegionServer GC 时间。

对于恢复正在进行的写操作，由于需要恢复 WAL，最坏情况是找到仅存的一个 block（即2个RegionServer挂掉），所以如果 HBase 的 timeout 时间为 60s 的话，则 HDFS 需设置为 20s 无响应的话即认为 DataNode 挂掉。在 HDFS 中，若一个 DataNode 被宣告死亡，则其复本需复制到其他存活的 DataNode 上，显然，这个操作是很消耗资源的。如果多个 DataNode 同时被宣告死亡，将引发"replication storms"： 大量复本都需要复制，导致系统过载，部分节点压力过大，无法发送心跳信息，进而这些节点被宣告死亡，这又导致这些节点上的复本需要复制，依此循环。基于这个原因，HDFS 在启动恢复进程前会先等待一段时间（大于10分钟），对于 HBase 这样的低延迟系统，显然这是无法接受的。在 [HDFS 1.2](https://issues.apache.org/jira/browse/HDFS-3912) 的版本后，引入了一个特殊状态：`stale` -- 若在指定时间内 HDFS 节点没发送心跳信息，则标记该节点状态为 stale。该状态的节点不能接收写请求，对于读请求，也是优先选择非 stale 的节点。在 [hdfs-site.xml](https://github.com/apache/hadoop/blob/branch-2.8.0/hadoop-hdfs-project/hadoop-hdfs/src/main/resources/hdfs-default.xml) 中，设置 stale 的配置如下：

```
<property>
   <name>dfs.namenode.avoid.read.stale.datanode</name>
   <value>true</value>
</property>

<property>
   <name>dfs.namenode.avoid.write.stale.datanode</name>
   <value>true</value>
</property>

<property>
   <name>dfs.namenode.write.stale.datanode.ratio</name>
   <value>1.0f</value>
   <description>
    When the ratio of number stale datanodes to total datanodes marked
    is greater than this ratio, stop avoiding writing to stale nodes so
    as to prevent causing hotspots.
   </description>
</property>
```

通过上面配置，Region 恢复将只与 HBase 有关。

## 参考
- [INTRODUCTION TO HBASE MEAN TIME TO RECOVERY (MTTR)](http://hortonworks.com/blog/introduction-to-hbase-mean-time-to-recover-mttr/)
- [HBASE-5843](https://issues.apache.org/jira/browse/HBASE-5843)

