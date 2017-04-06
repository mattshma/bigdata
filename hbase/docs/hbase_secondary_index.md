# HBase Secondary Index

HBase做为KV型数据库，Rowkey的设计十分重要，好的Rowkey需在查询条件和响应速度两方面满足业务需求。但在实际过程中，无论如何设计Rowkey，也可能出现单一Rowkey无法满足需求的情况，因此HBase引入二级索引的呼声也一直很高。

## Rowkey的设计原则



业务表Sample如下：

 RowKey          |             CF(info)
-----------------|-------------------------------------------------------
aid-bid-datetime |     info:aid  |   info:bid   |   info:cid |  info:did


## 二级索引方案
顾名思义，二级索引即在要查询的字段与一级索引建立一种映射关系。根据映射关系的存入位置，有如下两种方案。

### 表索引
使用单独的HBase表存储映射关系，查询条件组成一个Rowkey，Value即为对应的一级索引。对于表Sample，现在需通过cid-did 查询表中的数据，可建立索引表Index，该表Rowkey为 cid-did，value为表Sample中对应的aid-bid-datetime。

### 列索引
列索引即将索引列建在业务表上。为避免带来副作用，需要在逻辑上和物理上将索引数据与业务数据区分开。为提高性能，最好将索引数据与业务数据放在同一个Region中，此后查找一级Rowkey直接在Region进行，而不再需要全表扫描。通过合理的设计Rowkey前缀，可将索引数据全排在业务数据前面，这样做到了数据的逻辑区分。由于Region由一个或多个Store文件组成，每个Store只存储一个列族，因此索引列单独使用一个列族，可在物理上隔离索引数据与业务数据。

这里还是以Sample表为例，说下Rowkey的设计，首先建表时指定分区[0000, 0099], [0100, 0199]...[9900, 9999]，这样有100个分区，对于业务数据的rowkey，格式为四位hash前缀-aid-bid。各rowkey的hash前缀值为其所在region起始值外的其他任意值，如对于region1，其hash前缀为[0001, 0099]，其余依此类推。对于索引数据，rowkey格式曾四位hash前缀-查询条件代码-查询条件值-aid-bid，四位hash值为各region的起始值，如0000。若分别查询cid=01, did=02，其rowkey可以为0000-cid|bid-01|02-aa-02，查看aid=aa，cid=03，did=05，则rowkey为0000-aid|cid|did-aa|03|05-aa-03。



## 实现

### Phoenix

参考[Phoenix Secondary Indexing](https://phoenix.apache.org/secondary_indexing.html)

### Lily

从上可以看到，无论哪种设计，很重要的一点是将索引数据与业务放在同一个RegionServer甚至更细的粒度（如Region）。

## 参考
- [HBase Rowkey Design](http://archive.cloudera.com/cdh5/cdh/5/hbase-1.0.0-cdh5.6.0/book.html#rowkey.design)
- [Secondary Indexes and Alternate Query Paths](http://hbase.apache.org/book.html#secondary.indexes)
- [HBase高性能复杂条件查询引擎](http://www.infoq.com/cn/articles/hbase-second-index-engine)
- [Secondary Indexing In HBase: A tale of how to screw up a simple idea by breaking all the rules](https://www.linkedin.com/pulse/secondary-indexing-hbase-tale-how-screw-up-simple-idea-michael-segel?articleId=7019091741337614180#comments-7019091741337614180&trk=sushi_topic_posts)
