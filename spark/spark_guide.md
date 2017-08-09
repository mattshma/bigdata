# Spark 速览

*注：本文源自官方文档，旨在整理 Spark 基础操作，方便查看。*

## Overview

编写 Spark 程序，一般先创建一个 SparkConf 对象，设置程序相关信息，然后通过该 SparkConf 对象创建一个 SparkContext 对象，通过该对象连接 Spark 集群。每个 JVM 只能运行一个 SparkContext 对象，若需要新建一个 SparkContext，需要先调用当前 SparkContext 的 stop() 方法停掉当前 SparkContext。

在 Spark Shell 中，内置了一个 SparkContext 对象，其名为 `sc`。在启动 Spark Shell 时，可指定 `--master` 参数让 `sc` 连接相应 Spark 集群。

## Resilient Distributed Datasets (RDDs)
RDD 是 Spark 的核心概念，其是分布在集群各节点上的元素的容错集合，因此其能并行(parallel)执行。有两种方法能创建 RDD 对象：并行化程序中已经存在的集合，如`sc.parallelize(collection)`；创建与外部存储系统关联的 dataset，如`sc.textFile("data.txt")`，注意此方法需要所有 worker node 都能访问到该文件，即若使用本地文件系统，则所有 worker node 都需要能在相同路径下访问到该文件。

RDD 支持两种类型的操作：转换（transformation） 和 动作（action）。转换即从已存在的 dataset 中生成新的 dataset，如`map`，动作即运行 dataset 并返回一个值，如`reduce`。在 Spark 中，所有转换都是懒惰的(lazy)，即它们不会立即执行，只有需要时才执行。

默认情况下，每个转换过的 RDD 在被执行动作时可能会重新计算一次，当然也可调用 persist/cache 方法将其存储在内存或磁盘中，这样下次查询该 RDD 时速度会快很多。

### 传递函数给 Spark
在 scala 中，推荐两种方法将函数传递给 Spark：
- [匿名方法语法](https://www.scala-lang.org/old/node/133.html)，可以在较短的代码中使用。
- 全局单例对象里的静态方法。

### 闭包
考虑如下代码：
```
var counter = 0
var rdd = sc.parallelize(data)

// Wrong: Don't do this!!
rdd.foreach(x => counter += x)

println("Counter value: " + counter)
```

在集群模式中，对于该 Job， Spark 分拆成多个 task，每个 executor 执行一个task。在执行 task 前，Spark 会计算该 task 的闭包，并将闭包序列化后传输给每个 executor。而各 executor 节点只能看到自己节点上的 counter 变量，不能访问 driver 节点的 counter 变量，因此 driver 节点上 counter 变量的最终值仍为0。在本地模式中，foreach 可能在一个 JVM 执行，因此可能最终会更新 counter。为避免这种情况发生，需使用 Accumulator 来实现 counter，后续再具体说明。

