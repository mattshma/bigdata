# HBase Split


## Split方式
Hbase有三种split方式，如下一一阐述。

### Pre-splitting

在新建表时，可预先给表分region，这样可有效解决热region的问题。命令如下：
```
> create 'table', 'cf', SPLITS => ['rowkey1', 'rowkey2', 'rowkey3']
或
> create 'table', 'cf', SPLITS_FILE => '/home/hadoop/splitfile.txt'
其中/home/hadoop/splitfile.txt中存储内容如下：
rowkey1
rowkey2
rowkey3
```

若不能很好的预测分区，可使用HBase自带的pre-split算法--[HexStringSplit](https://hbase.apache.org/devapidocs/org/apache/hadoop/hbase/util/RegionSplitter.HexStringSplit.html)和[UniformSplit](https://hbase.apache.org/devapidocs/org/apache/hadoop/hbase/util/RegionSplitter.UniformSplit.html)。如果rowkey使用十六进制作为前缀，可以使用HexStringSplit，如

```
hbase org.apache.hadoop.hbase.util.RegionSplitter pre_split_table HexStringSplit -c 10 -f f1
```

### 自动拆分

目前自动拆分策略有如下几种策略，通过`hbase.regionserver.region.split.policy`进行设置，当前默认拆分策略为IncreasingToUpperBoundRegionSplitPolicy。


#### ConstantSizeRegionSplitPolicy
在0.94之前，该策略为默认策略，当某个StoreFile达到`hbase.hregion.max.filesize`（默认10G）时，region会自动split。

#### IncreasingToUpperBoundRegionSplitPolicy
在0.94及之后版本，该策略为默认策略。这个策略中，分裂与RegionServer中Region个数有关，即StoreFile大小达到如下[公式](https://hbase.apache.org/devapidocs/org/apache/hadoop/hbase/regionserver/IncreasingToUpperBoundRegionSplitPolicy.html)的值时会发生split：`Min (R^3 * "hbase.hregion.memstore.flush.size" * 2 , "hbase.hregion.max.filesize")`，R为同一RegionServer中同一表的Region数。若`hbase.hregion.memstore.flush.size`为128MB，`hbase.hregion.max.filesize`为10G，则R=3后时，StoreFile Split大小由`hbase.hregion.max.filesize`决定。		

#### BusyRegionSplitPolicy
split基于Region繁忙程度。Region繁忙程度由`hbase.busy.policy.aggWindow`(单位ms)衡量。具体参见[BusyRegionSplitPolicy](https://hbase.apache.org/devapidocs/org/apache/hadoop/hbase/regionserver/BusyRegionSplitPolicy.html)。

#### KeyPrefixRegionSplitPolicy
根据rowkey的前缀对数据分组，需要指定rowkey的前多少位做为前缀，如rowkey是20位，指定前5位为前缀，则前5位相同的rowkey在split时会分到相同的region中。见[KeyPrefixRegionSplitPolicy](https://hbase.apache.org/devapidocs/org/apache/hadoop/hbase/regionserver/KeyPrefixRegionSplitPolicy.html)。

#### DelimitedKeyPrefixRegionSplitPolicy
根据前缀及分隔符对数据分组。如row_key类型为userid_eventtype_eventid，指定分隔符为_，则split后相关userid的会被分到同一region中。见[DelimitedKeyPrefixRegionSplitPolicy](https://hbase.apache.org/devapidocs/org/apache/hadoop/hbase/regionserver/DelimitedKeyPrefixRegionSplitPolicy.html)。

#### DisabledRegionSplitPolicy
关闭自动split。

各策略关系如下：
```
org.apache.hadoop.hbase.regionserver.RegionSplitPolicy
	org.apache.hadoop.hbase.regionserver.ConstantSizeRegionSplitPolicy
		org.apache.hadoop.hbase.regionserver.IncreasingToUpperBoundRegionSplitPolicy
			org.apache.hadoop.hbase.regionserver.BusyRegionSplitPolicy
			org.apache.hadoop.hbase.regionserver.DelimitedKeyPrefixRegionSplitPolicy
			org.apache.hadoop.hbase.regionserver.KeyPrefixRegionSplitPolicy
	org.apache.hadoop.hbase.regionserver.DisabledRegionSplitPolicy
```
### 手动split
在hbase shell中，可手动进行split：`split 'table', 'split_key'`。


## Split过程
整个过程参考[RegionServer Splitting Implementation](https://github.com/apache/hbase/blob/master/src/main/asciidoc/_chapters/architecture.adoc#65-regionserver-splitting-implementation)，以下稍微说下：

![region_split_process.png](https://github.com/apache/hbase/blob/master/src/main/site/resources/images/region_split_process.png)

- RegionServer决定split region，启动split事务。RegionServer先获取表的共享读锁，以免split过程中表结构变化。接着在Zookeeper中创建znode`/hbase/region-in-transition/region-name`，并将该znode的状态设为Splitting。
- 由于Master监听`/hbase/region-in-transition`目录，因此知道该region需要做split。
- RegionServer在hdfs中该region目录下创建`.splits`子目录。
- RegionServer关闭该region，强制flush memstore，并在RegionServer中将该region标记为offline状态，如果此时客户端刚好请求该region，会抛出NotServingRegionException异常，之后客户端会重试。
- RegionServer在`.splits`目录下分别为两个子region创建目录和必要的数据结构，然后创建两个引用文件指向该region（即子region的父region）中的文件。
- RegionServer在hdfs中创建真正的region目录，并将引用文件移到对应目录下。
- RegionServer发送一个put请求给hbase:meta表，在hbase:meta表将该region标记为offline状态，并将子region信息也加入到hbase:meta中。此时如果scan hbase:meta，会发现该region正在split。如果这个put请求成功，即表示split信息更新成功，若put失败，Master和下次打开该region的RegioinServer会清除这次关于split的脏状态。
- RegionServer并行打开两个子目录接收写操作。
- RegionServer在hbase:meta表增加两个子目录的相关信息。此后客户端发现这2个region并清除本地缓存的hbase:meta信息，重新访问hbase:meta并更新本地缓存。
- RegionServer更新Zookeeper中`/hbase/region-in-transition/region-name`的状态为Split，Master节点获取该状态，若有必要的话，balancer可能将子region迁移到其他RegionServer。此时split完成。
- split完成后，hbase:meta和hdfs中仍会在父region中保存引用文件，这些引用文件会在子region进行compaction时被删除。Master的垃圾回收任务会周期性的检查子region明是否还在引用父region，若没有，则父region被移除。


Split的源码分析见[HBase Split源码分析](hbase_sc_split.md)。

### 测试
在测试集群上自动split，观察log。

## 参考
- [HBase merge and split impact in HDFS](https://ctheu.com/2015/12/24/hbase-merge-and-split-impact-in-hdfs/)
