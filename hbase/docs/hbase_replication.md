# HBase Replication

需要注意的几点：
- 保证源集群和目标集群时间一致（建表使用 NTP 同步）
源集群中如下几种情况数据不会复制到目标集群：
- 开启复制前源集群中已存在的数据。
- 由于复制是通过 WAL 进行的，所以如果源集群中操作跳过 WAL 的话，则这些操作对应的数据也不会同步到目标集群，如 BulkLoad 或设置 writeToWal(false) 的 API 调用。
- 表结构修改。

zk结构。

read/filter/ship


何时会复制：
By default, a source will try to read from a log file and ship log entries as fast as possible to a sink. This is first limited by the filtering of log entries; only KeyValues that are scoped GLOBAL and that don't belong to catalog tables will be retained. A second limit is imposed on the total size of the list of edits to replicate per slave, which by default is 64MB. This means that a master cluster RS with 3 slaves will use at most 192MB to store data to replicate. This doesn't account the data filtered that wasn't garbage collected.



The edit is then tagged with the master's cluster UUID. When the buffer is filled, or the reader hits the end of the file, the buffer is sent to a random region server on the slave cluster.

## Q
1. 数据啥时候传输呢？从上看文件会立即传输，但有两个限制：1. only KeyValues that are scoped GLOBAL and that don't belong to catalog tables will be retained。 2. Once the maximum size of edits was buffered or the reader hits the end of the log file, the source thread will stop reading and will choose at random a sink to replicate to. buffer 默认大小为64M，即若读到 HLOG 末尾或 buffer 满了，会开始复制。这样数据量小的会在读到hlog尾时开始复制。

[64M](https://github.com/apache/hbase/blob/branch-1.2/hbase-server/src/main/java/org/apache/hadoop/hbase/replication/regionserver/ReplicationSource.java#L165)

内部

注意点：

默认复制因子为 [0.1](https://github.com/apache/hbase/blob/branch-1.2/hbase-server/src/main/java/org/apache/hadoop/hbase/replication/regionserver/ReplicationSinkManager.java#L57)

KEEP_DELETED_CELLS=true

目前replication 对于压缩的hlog的wal entry 无法解析？:http://blog.csdn.net/teriy/article/details/7968181

Replication_scope 能设置为2.。 If set REPLICATION_SCOPE to 2, we will push edits by the order of written.?


HLog Compression/Replication compatibility: HBase Replication is now compatible with HLog compression. This means a cluster with WAL compression can replicate its data to another cluster with no WAL compression, and vice versa. (See for details: HBASE-5778.)


status 'replication'参数说明.

## 参考
- [HBase Cluster Replication](http://hbase.apache.org/book.html#_cluster_replication)
- [HBase 0.94 replication overview](https://hbase.apache.org/0.94/replication.html)
- [HBase Replication](https://www.cloudera.com/documentation/enterprise/5-8-x/topics/cdh_bdr_hbase_replication.html#topic_20_11)
- [HBASE-17460](https://issues.apache.org/jira/browse/HBASE-17460)
- [HBASE-9531](https://issues.apache.org/jira/browse/HBASE-9531)
- [HBASE-5778](https://issues.apache.org/jira/browse/HBASE-5778)
