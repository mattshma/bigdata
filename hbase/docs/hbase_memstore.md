# HBase MemStore分析

## MemStore Flush

- hbase.hregion.memstore.flush.size
单个memstore能达到的上限值（默认为128M）。当memstore达到该值时，会触发memstore的flush操作，此时的flush不阻塞写操作。每隔`hbase.server.thread.wakefrequency`（默认值为10s）检查一次。

- hbase.hregion.memstore.block.multiplier
当一个region的memstore总量达到 `hbase.hregion.memstore.block.multiplier`(默认值为2) * `hbase.hregion.memstore.flush.size`时，会触发memstore的flush操作，并阻塞这个region的写操作。这种情况只发生在即将写满2*128M时再写入一个大对象时发生。

- hbase.regionserver.global.memstore.lowerLimit/upperLimit
一个RS可能会有多个Region，每个Region有多个memstore，所以可能单个Region没超过阈值，但整个RegionServer占用的内存已经非常多了，这时还有`hbase.regionserver.global.memstore.lowerLimit`和`hbase.regionserver.global.memstore.upperLimit`来控制memstore的flush。当RegionServer上所有memstore占用的大小达到RegionServer Java Heap的`hbase.regionserver.global.memstore.lowerLimit`（默认值为0.35）倍时，会选择一些占用内存比较大的memstore强制flush并阻塞这些memstore的写操作；若RegionServer所有memstore占用的内存大小达到RegionServer Java Heap的`hbase.regionserver.global.memstore.upperLimit`（默认为0.4）倍时，会阻塞该regionserver所有写操作并触发将rs所有memstore的flush操作。

- hbase.regionserver.maxlogs
WAL文件的数量的最大值，默认为32。由于数据通过WAL写入Memstore，当WAL大小达到`hbase.regionserver.maxlogs` * `hbase.regionserver.hlog.blocksize`(CDH中为HDFS的配置dfs.blocksize)时，为减小其大小，需要将memstore中数据flush到HLog，然后才能将这部分WALs删除。

- hbase.regionserver.optionalcacheflushinterval
为避免所有memstore在同一时间进行flush操作，会对memstore定期进行flush，默认时间为1小时。

- 手动flush

在hbase shell中，可针对某个表或某个Region进行flush。



 
