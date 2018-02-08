# 索引

## 主键索引
主键索引是分布式 hash 表与每台 Aerospike 节点中的分布式树型结构的混合。namespace 中的 key 空间通过 hash 算法分成了 partitions。整个集群共有 4096 个partitions。

Aerospike 节点上的树结构是红黑树节点，对于每个 partitions，可以有可配置数量的这种红黑树结构，称之为分枝（sprigs）。在设置合适数量的分枝时，需要考虑内存空间和优化并行访问。

主键索引位于一个 20 字节的 hash -- 主键索引的的 digest 中，当 record key 的原始大小不到 20 字节时，会对其进行扩展。当一台节点不可用时，其他节点与该节点 key 相同的备份 key 会立即可用，若该故障节点一直不可用，则会进行 rebalance，保证 key 的复本数不变。

### 索引的元数据
目前每个 index 条目大小为 64 字节，除了 20 字节的 digest 外，其他元数据也一样存在索引中：
- write generation：根据主键的所有更新操作，用于解决冲突的更新。
- 过期时间
- 上次更新时间
- 存储地址：数据存储地址。

### 索引持久化
为保证性能，主键索引只存在内存中。当 Aerospike 启动时，会扫描存储上的数据并对所有 partition 重建索引，这点类似 ElasticSearch。为了提高集群启动时间，Aerospike 提供了快速重启功能。快速重启需要设置 Linux 共享内存段（Linux shared memory segment），当重启时，节点会从共享内存中读取并激活索引数据。

### 单列优化
若开启单列（single bin）属性，Aerospike 会使用更少的内存存储数据。当所有单列值类型为 int 或 double 类型时，并且该 namespace 在索引中申明数据时会有更好的优化，此时主键索引中的空间会被复用存储 int 或 double 类型的值，即该 namespace 所需的存储空间只为其主键索引的存储空间。

## 二级索引

## 参考
- [Primary Index](https://www.aerospike.com/docs/architecture/primary-index.html)
- [Secondary Index](https://www.aerospike.com/docs/architecture/secondary-index.html)
