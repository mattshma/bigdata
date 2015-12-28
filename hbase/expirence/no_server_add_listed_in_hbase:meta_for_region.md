No server address listed in hbase:meta for region
---
部分表无法访问，原因是mata信息在hbase shell中发现报错：
```
> scan "table1"
ROW                                      COLUMN+CELL
ERROR: No server address listed in hbase:meta for region table1,,1425611935694.19175e504f2a4b1e9768fa1861f6e3b2. containing row
```
而且其`is_disabled`和`is_enabled`都是false。

进入`hbase zkcli`进入zookeeper中，删除相应表：`delete /hbase/table/table1`，然后重启集群，现在`is_enabled`为true了。但仍报`ERROR: No server address listed in hbase:meta for region table1`。
若先disable再enable该表，则报错：`ERROR: Table 'table1 not yet enabled, after 1230689ms.`

此时运行`hbase hbck -fixMeta -fixAssignments`发现该表`Deployed on`为空，同时报错如下：

```
ERROR: There is a hole in the region chain between  and .  You need to create a new .regioninfo and region dir in hdfs to plug the hole.
2015-10-12 14:06:21,226 INFO  [main] util.HBaseFsck: Handling overlap merges in parallel. set hbasefsck.overlap.merge.parallel to false to run serially.
ERROR: Found inconsistency in table table1
```


重建表
----

如果想删除表时报错表不存在，而新建该表时又提示这个表存在。则有3个地方需要清理下：

- hbase:meta中该文件meta信息：`delete "hbase:meta", "$rowkey", "$rs:column"`
- hdfs中该文件物理文件
- zookeeper中`/hbase/table/$table_name`

这三个位置清理干净后，重启服务就ok了。


