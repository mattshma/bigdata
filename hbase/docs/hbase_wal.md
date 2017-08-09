# WAL

为了避免服务器掉电丢失 Memstore 的数据，数据最先写入的是 WAL，然后才是 Memstore。WAL 的角色类似 Mysql 中的 Binlog，在 Memstore 数据丢失时，可用 WAL 来恢复数据。

## 概览
首先从直观上看下 WAL 相关信息。在 HDFS 上，关于 WAL 至少有两个目录：/hbase/WALs 和 /hbase/oldWALs。每个 RegionServer 在启动时都会分配一个由 host, port 和 startcode 组成的唯一标志，每个 RegionServer 对应一个 WAL，即每个 RegionServer 在 /hbase/WALs 中都有自己一个目录，该目录名由 host,port,stratcode 组成。整个 /hbase/WALs 目录下文件名组成为`/hbase/WALs/hostname,port,startcode/hostname%2Cport%2Cstartcode.timestamp`。

随着数据的不断写入，WAL 越来越大，当文件大小达到`hbase.regionserver.logroll.multiplier * hbase.regionserver.hlog.blocksize`时，会发生 WAL 滚动操作，其中`hbase.regionserver.logroll.multiplier`默认值为`0.95`，`hbase.regionserver.hlog.blocksize`大小默认为 HDFS 中`dfs.blocksize`大小，为 128M。另外，HBase 后台有一个 LogRoller 线程每隔`hbase.regionserver.logroll.period`（默认值为1小时）时间滚动 WAL，即使 WAL 大小小于阈值。当 RegionServer 下 WAL 文件数达到一定数目（默认为32，参见[源码](https://github.com/apache/hbase/blob/branch-1.2/hbase-server/src/main/java/org/apache/hadoop/hbase/regionserver/wal/FSHLog.java#L522)）时，会触发 Memstore 的 Flush 操作，对于已写入 HFile 的数据，其对应的 WAL 文件会被移到 /hbase/oldWALs 目录。

## WAL 剖析
查看 [WAL源码](https://github.com/apache/hbase/blob/branch-1.2/hbase-server/src/main/java/org/apache/hadoop/hbase/wal/WAL.java#L50)，知其由 Entry 构成，Entry 是 WAL 的最小存储单位。Entry 由 WALEdit 和 WALKey 构成，以下分别说下这两块内容。

### WALKey
查看 [WALKey](https://github.com/apache/hbase/blob/branch-1.2/hbase-server/src/main/java/org/apache/hadoop/hbase/wal/WALKey.java)，其主要属性有：

- encodedRegionName    
  Entry 对应的 Region。
- tablename    
  Entry 对应的表名。
- logSeqNum    
  Entry 的序列号。
- now   
  edit 的写入时间。
- clusterIds    
  Replication 时需要传输 WAL 的集群。
- mvcc  
  使用 mvcc 生成 writeEntry。

### WALEdit
每个 WALEdit 代表一个事务的 edit（KeyValue 对象）集合，每个 put 或 delete 操作都会封装成一个 WALEdit 实例。 查看 [WALEdit](docs/https://github.com/apache/hbase/blob/branch-1.2/hbase-server/src/main/java/org/apache/hadoop/hbase/regionserver/wal/WALEdit.java)，其主要属性有：

- METAFAMILY  
- METAROW
- COMPACTION
- FLUSH
- REGION_EVENT
- BULK_LOAD
- isReplay

根据上述属性，可创建 FlushWALEdit, RegionEventWALEdit, Compaction 等不同的 WALEdit。

### FSHLog
[FSHLog](https://github.com/apache/hbase/blob/branch-1.2/hbase-server/src/main/java/org/apache/hadoop/hbase/regionserver/wal/FSHLog.java#L522) 是 WAL 的实现类，其主要实现了 append() 和 sync() 方法，并引入 [LMAX Disrutpor RingBuffer](https://github.com/LMAX-Exchange/disruptor/wiki/Introduction) ，实现内部 SyncRunner 线程刷写文件到磁盘中。




## 参考
- [WAL](https://hbase.apache.org/book.html#wal)
- [Apache HBase Write Path](http://blog.cloudera.com/blog/2012/06/hbase-write-path/)
- [Hbase WAL 线程模型源码分析](https://www.qcloud.com/community/article/164816001481011969)
