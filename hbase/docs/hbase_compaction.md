# HBase Compaction

memstore flush会生成很多文件，如果这些文件达到阈值，会触发这些文件的compaction操作以减少文件数目，这个过程一直持续到这些文件中最大的文件超过配置的HRegion大小，然后会触发split操作。

compaction分为minor和major两种。minor只是将小文件合并成一个大文件，不删除数据。major会对region下的所有storeFile执行合并操作并最终生成一个文件。

## minor compaction

如下参数会影响minor compaction：

- hbase.hstore.compaction.min   
  每个Store中需要compaction的StoreFile数目的最小值，默认值为3。调优该值的目标是避免过多太小的StoreFiles进行compact。若其值设置为2，每次一个Store有2个StoreFile都会触发一次minor compaction，这并不太合适。若该值设置太大，需要其他影响minor compaction的值也设置合理。对于大多数情况而言，默认值都能满足。
- hbase.hstore.compaction.max    
  触发单个minor compaction的最大StoreFile数。
- hbase.hstore.compaction.min.size    
  小于该值的StoreFile自动做为需要minor compaction的StoreFile。该值默认同`hbase.hregion.memstore.flush.size`，即128Mb。对于写压力较大的场景，该值可能需要调小。因为这种使用场景中小文件非常多，即使StoreFile做了minor compaction后，新生成文件的大小仍小于该值。
- hbase.hstore.compaction.max.size      
  大于该值的StoreFile自动从minor compaction中排除。该值默认为9223372036854775807 byte，即`LONG.MAX_VALUE`。
- hbase.hstore.compaction.ratio   
  对于minor compaction而言，该值能判断大于`hbase.hstore.compaction.min.size`的StoreFile是否会被compaction，将StoreFile按年龄排序，若该文件的大小小于minor compaction后生成文件的大小乘以该ratio的话，则该文件也就做minor compaction，minor compatcion总是从老文件开始选择。如ratio为1，文件从老到新大小依次为100，50, 23, 12 和 12 字节，`hbase.hstore.compaction.min.size`为10，由于`100>(50+23+12+12)*1`和`50>(23+12+12)*1`，所以100，50不会被compaction，而由于`23<(12+12)*0.1`，所以23及比其小的12（文件个数须小于hbase.hstore.compaction.max）均应被compaction。该值是浮点数，默认为1.2。
- hbase.hstore.compaction.ratio.offpeak    
  低峰期时可设置不同的ratio用以让大尺寸的StoreFile进行compaction，方法同`hbase.hstore.compaction.ratio`，该值仅当`hbase.offpeak.start.hour`和`hbase.offpeak.end.hour`开启时才生效。

## major compaction
major compaction会合并Region下所有StoreFile最终生成一个文件。触发major compaction的条件有：major_compact、majorCompact() API、RegionServer自动运行。影响RegionServer自动运行的相关参数如下：

- hbase.hregion.majorcompaction    
  每次执行major compaction的时间间隔，默认为7天。若设置为0，即禁止基于时间的major compaction。若major compaction对影响较大，可将该值设为0，通过crontab或其他文件来执行major compaction。

- hbase.hregion.majorcompaction.jitter    
为防止同一时间运行多个major compaction，该属性对`hbase.hregion.majorcompaction`规定的时间进行了浮动，该值默认值为0.5，即默认情况下major compaction时间在[7-7*0.5天, 7+7+0.5天]这个范围内。

## 参考
- [hbase-default.xml](https://github.com/apache/hbase/blob/master/hbase-common/src/main/resources/hbase-default.xml)
- [Regions](http://hbase.apache.org/0.94/book/regions.arch.html)
