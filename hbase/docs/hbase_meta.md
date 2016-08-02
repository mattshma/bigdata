# hbase:meta表简介

## hbase:meta介绍
在0.96之前的版本中，hbase的meta信息通过-ROOT-表来查询，在0.96.0之后的版本中，移除了-ROOT-表，.meta.被重重命名为hbase:meta，并且其位置存储在zookeeper中。

```
# hbase shell
> scan 'hbase:meta', LIMIT=>1
TestTable,00000000000000000000183519,14 column=info:regioninfo, timestamp=1457515420191, value={ENCODED => fbc3f12f6e05daa4ec0b17e431c4f509, NAME => 'TestTab
 57515419490.fbc3f12f6e05daa4ec0b17e431c le,00000000000000000000183519,1457515419490.fbc3f12f6e05daa4ec0b17e431c4f509.', STARTKEY => '000000000000000000001835
 4f509.                                  19', ENDKEY => '00000000000000000000367087'}
 TestTable,00000000000000000000183519,14 column=info:seqnumDuringOpen, timestamp=1461725865195, value=\x00\x00\x00\x00\x00\x00\x03\x1E
 57515419490.fbc3f12f6e05daa4ec0b17e431c
 4f509.
 TestTable,00000000000000000000183519,14 column=info:server, timestamp=1461725865195, value=10-2-96-43:60020
 57515419490.fbc3f12f6e05daa4ec0b17e431c
 4f509.
 TestTable,00000000000000000000183519,14 column=info:serverstartcode, timestamp=1461725865195, value=1461665925512
 57515419490.fbc3f12f6e05daa4ec0b17e431c
 4f509.
```

rowkey即为每个Region的Name，rowkey的格式为：`tableName,regionStartKey,regionId.encodedRegionName`，regionId通常是[region创建的时间点](https://hbase.apache.org/apidocs/src-html/org/apache/hadoop/hbase/HRegionInfo.html#line.375)。encodedRegionName是对RegionName中`.`前部分（即`tableName,regionStartKey,regionId`）的md5 hash。根据rowkey可以找到相应region在hdfs中的位置：`/<hbaseRootDir>/<tableName>/<encodedRegionName>/<columnFamily>/<fileName>`。fileName是基于Java内建的随机数生成器产生的任意数字。

每个rowkey在info列族有[如下列](https://github.com/apache/hbase/blob/master/hbase-client/src/main/java/org/apache/hadoop/hbase/MetaTableAccessor.java)：

>info:regioninfo         => contains serialized HRI for the default region replica
 info:server             => contains hostname:port (in string form) for the server hosting
                            the default regionInfo replica
 info:server_<replicaId> => contains hostname:port (in string form) for the server hosting the
                            regionInfo replica with replicaId
 info:serverstartcode    => contains server start code (in binary long form) for the server
                            hosting the default regionInfo replica
 info:serverstartcode_<replicaId> => contains server start code (in binary long form) for the
                                     server hosting the regionInfo replica with replicaId
 info:seqnumDuringOpen    => contains seqNum (in binary long form) for the region at the time
                             the server opened the region with default replicaId
 info:seqnumDuringOpen_<replicaId> => contains seqNum (in binary long form) for the region at
                             the time the server opened the region with replicaId
 info:splitA              => contains a serialized HRI for the first daughter region if the
                             region is split
 info:splitB              => contains a serialized HRI for the second daughter region if the
                             region is split
 info:mergeA              => contains a serialized HRI for the first parent region if the
                             region is the result of a merge
 info:mergeB              => contains a serialized HRI for the second parent region if the
                             region is the result of a merge
>

一般而言，在`hbase:meta`表中，正常的region会有`info:regioninfo`、`info:server`、`info:serverstartcode`等列，`info:regioninfo`

info:regioninfo等如何产生？为什么只有reioninfo信息没其他信息。

如何修复？

## zookeeper


## 参考
- [What are HBase znodes](http://blog.cloudera.com/blog/2013/10/what-are-hbase-znodes/)
- [hbase-meta](https://github.com/XingCloud/HMitosis/wiki/hbase-meta)
