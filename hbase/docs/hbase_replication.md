# HBase Replication

需要注意的几点：
- 保证源集群和目标集群时间一致（建表使用 NTP 同步）
源集群中如下几种情况数据不会复制到目标集群：
- 开启复制前源集群中已存在的数据。
- 由于复制是通过 WAL 进行的，所以如果源集群中操作跳过 WAL 的话，则这些操作对应的数据也不会同步到目标集群，如 BulkLoad 或设置 writeToWal(false) 的 API 调用。
- 表结构修改。



## 参考
- [HBase Replication](https://www.cloudera.com/documentation/enterprise/5-8-x/topics/cdh_bdr_hbase_replication.html#topic_20_11)
- [Replication Overview](https://github.com/apache/hbase/blob/master/src/main/asciidoc/_chapters/ops_mgt.adoc#61-replication-overview)
- [HBASE-17460](https://issues.apache.org/jira/browse/HBASE-17460)
