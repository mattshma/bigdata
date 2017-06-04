# HBase Configuration 
目前在做 HBase Client 相关的一些工作，由于涉及到 client 端的一些优化，这里整理一版脱水版的配置，做全局查看用。

HBase Version: 1.2.x

## hbase-default.xml 默认配置

### Client configurations

name | value  | description
-----------------------|-------------------------|-----------------------
hbase.client.write.buffer | 2097152              | client write buffer 的 bytes 大小。 server 端需要实例化 client 传过来的 write buffer，所以较大的 write buffer 同时在 client 和 server 端占用更多内存，server 端占用内存为 `hbase.client.write.buffer` * `hbase.regionserver.handler.count`。
hbase.client.pause | 100 | client 暂停时间因子，单位为 ms，与 [RETRY_BACKOFF](https://github.com/apache/hbase/blob/branch-1.2/hbase-common/src/main/java/org/apache/hadoop/hbase/HConstants.java#L583) 相乘的积为重试间隔时间。
hbase.client.retries.number | 35 | 最大重试次数。见 RETRY_BACKOFF 。
hbase.client.max.total.tasks | 100 | 单个 HTable 实例可以提交的最大并发任务数。


## 参考
- [hbase-default.xml](https://github.com/apache/hbase/blob/branch-1.2/hbase-common/src/main/resources/hbase-default.xml)
- [hbase-default.adoc](https://github.com/apache/hbase/blob/branch-1.2/src/main/asciidoc/_chapters/hbase-default.adoc)
