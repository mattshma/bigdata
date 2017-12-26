# Spark 速览

*注：本文源自官方文档，旨在整理 Spark 基础操作，方便查看。*

## Overview

编写 Spark 程序，一般先创建一个 SparkConf 对象，设置程序相关信息，然后通过该 SparkConf 对象创建一个 SparkContext 对象，通过该对象连接 Spark 集群。每个 JVM 只能运行一个 SparkContext 对象，若需要新建一个 SparkContext，需要先调用当前 SparkContext 的 stop() 方法停掉当前 SparkContext。

在 Spark Shell 中，内置了一个 SparkContext 对象，其名为 `sc`。在启动 Spark Shell 时，可指定 `--master` 参数让 `sc` 连接相应 Spark 集群。

## Resilient Distributed Datasets (RDDs)
RDD 是 Spark 的核心概念，其是分布在集群各节点上的元素的容错集合，因此其能并行(parallel)执行。有两种方法能创建 RDD 对象：
- 并行化程序中已经存在的集合，如`sc.parallelize(collection)`；
- 创建与外部存储系统关联的 dataset，如`sc.textFile("data.txt")`，注意此方法需要所有 worker node 都能访问到该文件，即若使用本地文件系统，则所有 worker node 都需要能在相同路径下访问到该文件或使用共享存储访问该文件。

RDD 支持两种类型的操作：
- 转换(transformation)        
转换即从已存在的 dataset 中生成新的 dataset，如`map`。在 Spark 中，所有转换都是懒惰的(lazy)，即它们不会立即执行，只有需要时才执行。
- 动作(action)       
动作即运行 dataset 并返回一个值，如`reduce`。默认情况下，每个转换过的 RDD 在执行动作(action)时可能会重新计算一次，当然也可调用 persist/cache 方法将其存储在内存或磁盘中，这样下次查询该 RDD 时速度会快很多。

如下例子：
```
val lines = sc.textFile("data.txt")
val lineLengths = lines.map(s => s.length)
val totalLength = lineLengths.reduce((a, b) => a + b)
```

- 第一行通过外部文件定义一个 RDD。此时文件不会立即加载到内存中，`lines` 只是指向文件的一个指针。
- 第二行定义 `map` 转换的结果。`lineLengths` 由于懒惰性，不会立即计算。
- 第三行执行了 `reduce` 这个动作。此时 Spark 将计算分为几个任务分到各个 executor 上执行，最终返回结果给 driver 程序。
- 如果后续想重新使用 `lineLengths`，在调用 `reduce` 之前，可将其保存到内存中：
```
lineLengths.persist()
```

### 传递函数给 Spark
在 scala 中，推荐两种方法将函数传递给 Spark：
- [匿名方法语法](https://www.scala-lang.org/old/node/133.html)，可以在较短的代码中使用。
- 全局单例对象里的静态方法。

### 闭包
Spark 中在集群上运行代码时，变量的范围和生命周期是一个较难理解的部分。下面以 `foreach()` 增加计数器为例讲解这部分。

考虑如下代码：
```
var counter = 0
var rdd = sc.parallelize(data)

// Wrong: Don't do this!!
rdd.foreach(x => counter += x)

println("Counter value: " + counter)
```

在集群模式中，对于该 Job， Spark 分拆成多个 task，每个 executor 执行一个task。在执行 task 前，Spark 会计算该 task 的闭包，并将闭包序列化后传输给每个 executor。而各 executor 节点只能看到自己节点上的 counter 变量，不能访问 driver 节点的 counter 变量，因此 driver 节点上 counter 变量的最终值仍为0。在本地模式中，foreach 可能在一个 JVM 执行，因此可能最终会更新 counter。为避免这种情况发生，需使用 Accumulator 来实现 counter，后续再具体说明。

另一个较常见的问题就是使用 `rdd.foreach(println)` 或 `rdd.map(println)` 打印 RDD 中元素。在单台机器上，这会打印出 RDD 的元素；但在集群模式下，输出将会写到 executor 的`stdout` 中，而 driver 将不会输出。为了在 driver 输出所有元素，可以先用 `collect()` 将 RDD 发送给 driver 节点然后再打印：`rdd.collect().foreach(println)`，不过这可能会导致 dirver 内存不足。若只需要输出少量元素，可使用 `take()`: `rdd.take(100).foreach(println)`。

### Transformations and Actions
常用的一些[Transformations](https://spark.apache.org/docs/latest/rdd-programming-guide.html#transformations);
常用的一些[Actions](https://spark.apache.org/docs/latest/rdd-programming-guide.html#actions)。

### Shuffle 

和 MapReduce 中的 shuffle 类似，Spark 中的 Shuffle 主要用于将数据拷贝到对应的 executor 中，因此该操作是一个复杂耗时的操作。

以[reduceByKey](https://spark.apache.org/docs/latest/rdd-programming-guide.html#ReduceByLink)为例，该操作生成一个新的RDD 对象，该对象是一个 KV 型的 tuple。在 Spark 中为得到所有 key 的 value，需从这些 key 的所有分区中读取这些 key 的value，然后针对每个 key 的 所有value 聚集在一起最终计算出一个值，这整个过程称为 shuffle。

Shuffle 分成两部分：map 用于组织数据，reduce 用于聚合数据。一般 Shuffle 在传输数据前会进行排序分区等操作，所有会消耗大量内存。若内存不足，数据会持久化部分到磁盘中，并可能造成 GC。为防止之后数据重复计算，Spark 会将这些中间文件临时保留到磁盘一段时间，临时目录由 `spark.local.dir` 配置。
由于 Shuffle 涉及了磁盘I/O，数据序列化，网络I/O 等昂贵操作，在实际生产中，Shuffle 是优化的重点，由于这块比较重要，后面会专门讲解这部分内容。

### RDD 持久化
Spark 一个很重要的功能是将数据持久化（或缓存）在内存中，当持久化 RDD 时，每个节点的内存存储了对应 patition 数据，以达到复用的目的。可使用 `persist()` 和 `cache()` 来持久化数据到内存中，这部分持久化数据是容错的 -- 如果 RDD 中的某一分区丢失，则其会自动根据产生它的转换（transformation）重新计算。

持久化 RDD 时有不同的级别，如下：

存储级别 |  涵义
---------|---------
 MEMORY_ONLY | 将 RDD 以反序列化 Java 对象存储在 JVM 中，默认级别。若内存无法存储该 RDD，则部分分区不会存储在内存中，需要时重新计算这部分分区即可。
 MEMORY_AND_DISK | 将 RDD 以反序列化 Java 对象存储在 JVM 中。若内存无法存储该 RDD，则将多余的分区存储在磁盘中。
 MEMORY_ONLY_SER | 将 RDD 以序列化 Java 对象存储在 JVM 中。该方式比反序列化节省空间，不过需使用更多 CPU 时间读取。
 MEMORY_AND_DISK_SER | 同 MEMORY_ONLY_SER，对于不能存储在内存中的数据会转存到磁盘中。
 DISK_ONLY | 将RDD 分区全存在磁盘中。
 MEMORY_ONLY_2, MEMORY_AND_DISK_2, etc | 同上，不过将每个分区复制到两个集群节点中。
 OFF_HEAP (实验) | 同 MEMORY_ONLY_SER，不过是堆外内存，即没有 GC。

注：在 Python 中，RDD 对象都通过 [Pickle](https://docs.python.org/2/library/pickle.html)库进行了序列化，无论是否选择序列化。在 Python 中，能使用的存储级别为：MEMORY_ONLY, MEMORY_ONLY_2, MEMORY_AND_DISK, MEMORY_AND_DISK_2, DISK_ONLY, and DISK_ONLY_2。

在实际过程中，尽量选择 MEMORY_ONLY，其节省 CPU 时间，并能尽可能快的计算。其次使用 MEMORY_ONLY_SER 并选用尽可能快的序列化库。另外尽量少将数据转存到磁盘中，可能重新计算比从磁盘读取还快。

Spark 使用 LRU 剔除过期数据，若希望手动删除持久化的 RDD 数据，可使用 `RDD.unpersist()` 方法。


### 共享变量

Spark 主要有 Broadcast 变量和 Accumulators 两种类型。

- [Spark Programming Guide](https://spark.apache.org/docs/latest/rdd-programming-guide.html)
