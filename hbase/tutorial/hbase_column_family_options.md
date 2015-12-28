HBase 建表时的一些参数分析
===

对于HBase而言，选择合适的参数如同关系型数据库中选择引擎或CHAR vs VARHCAR vs TEXT 一样重要，这些参数对数据存取改删等都有影响。

compression
---

默认情况下 HBase 不对数据进行压缩，但实际上有两种压缩方式：BLOCK，RECORD

### Block compression

如果 HBase 表中某列的值是一个很大的文本数据，

参考
---

- [Understanding HBase column-family performance options](http://jimbojw.com/wiki/index.php?title=Understanding_HBase_column-family_performance_options)
- [Appendix E. Compression and Data Block Encoding In HBase](http://hbase.apache.org/book/compression.html)

