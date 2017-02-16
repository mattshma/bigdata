# HBase Timeline Consistency 

在 MTTR 中提到 RegionServer 异常情况下的优化措施，不过对于部分场景，相比花很长时间获取正常数据而言，其也接收获取过期数据的情况。对于这种场景，HBase提供 Read Replics 方案。

## HBase Read Replicas
Read Replicas，顾名思义即读可以多备份。开启 Read Replicas 后，除了某 RegionServer 拥有的默认 Region 外，HMaster 将多个只读 Region Replica 发送给不同的 RegionServer，默认 Region Replica 称为 **primary** replica，只读 Region Replicas 被称为 **secondaries** replica。secondary replicas 周期性的（由参数`hbase.regionserver.storefile.refresh.period`设置）读取 primary replica 的 HFile或通过复制（参数`hbase.region.replica.replication.enabled`设置）来更新数据，显然，若选择周期性更新的话，对于 primary replica 中 memstore 的数据，secondary regions 将暂时无法更新。所有拥有 replica 的region 都能处理读请求，不过 secondary regions 返回的数据会被标记为 "stale"，客户端能检测数据是否为 "stale"；另外，只有 primary region 能处理写请求。

Region Replicas 尽可能的分布在不同机架上的不同机器中来保证高可用，一旦某机器宕机，可选择另外一台机器进行 GET 或 SCAN 操作，读取的数据可能是过期数据，这部分数据的取舍由用户端自行选择。


## Timeline Consistency
HBase 默认一致性策略为 Strong Consistency，即读写请求只发送给相应的一个 Region。另外 HBase 还提供 Timeline Consistency 策略，即发送请求给所有拥有指定数据的 Region Replicas -- 读请求会先发送给 primary region，如果 `hbase.client.primaryCallTimeout.get` （默认为10ms） 时间内未收到 primary replica 的应答，再并发的将读请求发送给所有 secondary replicas。通过 Result.isStale() 能知道响应信息是否为 primary replica 返回。如果响应信息由 primary replica 返回，则数据为最新数据。

### 优缺点

优点：
- 只读表的高可用
- 过期数据读的高可用
- 对于 99.9% 的读取过期数据的请求保持低延迟

缺点：
- 多份 MemStore 空间占用
- 占用 BlockCache 的使用
- 复制 HFile 时会产生额外的网络开销
- 若 primary replicas 响应不及时，会产生额外的 RPC 开销。

关于 Timeline Consistency 的更多信息，可参考 [官方文档](https://github.com/apache/hbase/blob/master/src/main/asciidoc/_chapters/architecture.adoc#102-timeline-consistency)。

## Read Replicas 配置

### 服务端配置
如下：

 属性  |   设置值  |  说明
--------|------------|----------
hbase.region.replica.replication.enabled   | true | 若设置为 true，将通过复制来保证各 replicas 的数据同步，此时CF 上的 `REGION_MEMSTORE_REPLICATION`必须设置为 false。
hbase.region.replica.replication.memstore.enabled | true | 
hbase.regionserver.storefile.refresh.period | 0 (disabled)  | 通过拷贝 primary replica 的 HFile 来保证数据同步。如果周期设置过短，会加重 Namenode 的负担，若周期设置过长，sencondary replicas 的数据与 primary replica 的数据同步会不太及时。
hbase.regionserver.meta.storefile.refresh.period | 300000ms | `hbase:meta` 表 sencondary replicas 同步 primary replica 的频率。
hbase.master.hfilecleaner.ttl | 3600000ms |
hbase.meta.replica.count | 3 | 
hbase.region.replica.storefile.refresh.memstore.multiplier | 4 |
hbase.region.replica.wait.for.primary.flush | true | 
hbase.master.loadbalancer.class   | org.apache.hadoop.hbase.master.balancer.StochasticLoadBalancer | 读取 sencondary replicas 时的负载均衡以平摊请求。


### 客户端配置
如下：

属性 | 设置值 | 说明
--------|--------|-----------
hbase.ipc.client.specificThreadForWriting    | true | HBase 1.0.x 版本使用 `hbase.ipc.client.specificThreadForWriting` 而非该参数。
hbase.client.primaryCallTimeout.get   | 10ms | 
hbase.client.primaryCallTimeout.multiget  | 10ms | 
hbase.client.replicaCallTimeout.scan | 10ms | 
hbase.meta.replicas.use | true | 

### 激活 Read Replicas

建表时指定`REGION_REPLICATION`即可，如`hbase> create 'myTable', 'myCF', {REGION_REPLICATION => '3'}`。

## 参考
- [Timeline-consistent High Available Reads](https://github.com/apache/hbase/blob/master/src/main/asciidoc/_chapters/architecture.adoc#10-timeline-consistent-high-available-reads)
- [HBase Read Replicas](https://www.cloudera.com/documentation/enterprise/5-4-x/topics/admin_hbase_read_replicas.html)
- [HBASE-10070](https://issues.apache.org/jira/browse/HBASE-10070)
- [HBASE-10525](https://issues.apache.org/jira/browse/HBASE-10525)
