# HBase Architecture

## Overview
HBase有如下特性：

- 强一致性
- 自动分片
- RegionServer 自动故障转移
- 整合Hadoop/HDFS
- 支持MapReduce
- 提供Java Client API
- 提供Thrift/REST API
- Block Cache 和 Bloom Filter
- 便于管理

> [CAP定理](https://zh.wikipedia.org/wiki/CAP%E5%AE%9A%E7%90%86)指出对于一个分布式系统而言，不可能同时满足以下三点：
- 一致性（Consistence）
- 可用性（Availability）
- 网络分区容忍性（Partition tolerance）
对于分布式系统而言，分区容忍性是基本要求，所以在设计分布式数据系统时，需要在一致性和可用性中做权衡，但无论如何做权衡，都无法完全放弃一致性，如果真的放弃一致性，那么这个系统中的数据就变得不可信了。一般而言，分布式数据系统会牺牲部分一致性，使用最终一致性。
>
> 常见的一致性类型有：
> - 强一致性：当更新操作完成后，之后任意进程任何时间的请求的返回值都是一致的。
> - 弱一致性：更新完成后，系统并不保证后续请求的返回值是一致的（更新前和更新后的值都可能被返回），也不保证过多久返回的值一致。
> - 最终一致性：更新完成后，在“不一致窗口”后的请求的返回值都是一致。最终一致性是弱一致性的特例。
>

那么HBase是怎样保证强一致性的呢？


