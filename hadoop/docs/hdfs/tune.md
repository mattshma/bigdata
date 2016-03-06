# Hadoop调优

Hadoop集群搭建完成后，一般都要调整部分参数，以更好的利用集群。

## 原则

## 内存
以下从3方面说下内存的调整。
### 进程
默认情况下，Hadoop为namendoe, datanode, resourcemanager, nodemanager等进程分配的内存为1G。namenode需要的内存可大致计算得到：namenode维护文件系统中每个数据块的引用，而每个文件系统含有的数据块数，文件名长度等不同，所以各集群的namenode对内存的需求也不同。一般保守估计namenode需要为每1百万个数据块分配1G内存空间。以100个节点的集群算，每节点有12*4T的磁盘空间，数据块为64MB，复本为3，则约有100*12*4*1 000 000 MB/(64MB*3)=2500万个数据块，考虑到磁盘基本不会用完，所以该集群需要分配约20G内存给namenode。
 
### MR2
除这些守护进程外，还需给任务调整内存分配，在MR2中，分别使用`mapreduce.map.memory.mb`，`mapreduce.reduce.memory.mb`来限制map任务和reduce任务使用内存的大小，若任务使用内存使用超过`mapreduce.map/reduce.memory.mb`内存大小，会产生"Killing container"的问题。另外，map和reduce任务运行的JVM也可优化。若分配给任务运行的JVM内存太小，可能会产生"OutOfMemoryError"问题，若分配给其内存太大，可能会造成资源浪费。分配给每个任务的JVM大小由`mapred.child.java.opts`设置，默认为200MB，由于不大可能所有任务都使用同等大小jvm，因此可在客户端设置该属性(`-Xmx`)并覆盖配置文件中设置的值。在MR2版本中，若指定`mapreduce.map.java.opts`和`mapreduce.reduce.java.opts`，会覆盖`mapred.child.java.opts`设置的值。`mapreduce.map/reduce.memory.mb`限制任务使用内存的总大小，`mapreduce.map/reduce.java.opts`限制任务JVM使用内存大小，一般设置后者为前者的75%~80%左右，剩余内存留给JAVA代码。

### YARN

通过`yarn.nodemanager.resource.memory-mb`可指定每台nodemanager可分配的内存大小，如对于一台64G的nodemanager而言，若保留8G给操作系统及其他进程用，可将剩余的56G内存分给nodemanager用。

对于container而言，可通过`yarn.scheduler.minimum-allocation-mb`和`yarn.scheduler.maximum-allocation-mb`来分配设置单个container可用的最小和最大内存。

Nodemanager会检查container中虚拟内存和物理内存的使用情况，`yarn.nodemanager.vmem-pmem-ratio`用于指定虚拟内存与物理内存的比值，默认为2.1，即每使用1M的物理内存，最多使用2.1M的虚拟内存。默认情况下，当container使用的内存超过设置物理内存或虚拟内存时，都会发生"Killing container"的情况。container中任务物理内存的设置为上面提过的`mapreduce.map/reduce.memory.mb`，若超出该值则报错。若map/reduce任务使用的虚拟内存大于`yarn.nodemanager.vmem-pmem-ratio` * `mapreduce.map/reduce.memory.mb`，也会报错。可通过`yarn.nodemanager.pmem-check-enabled`和`yarn.nodemanager.vmem-check-enabled`停掉物理内存和虚拟内存的检查。

AM使用内存由`yarn.app.mapreduce.am.resource.mb`指定，AM的JVM的内存大小由`yarn.app.mapreduce.am.command-opts`指定。

### 整合
上面从几个点讲了内存的相关参数，这里引用[MapReduce YARN Memory Parameters](https://support.pivotal.io/hc/en-us/articles/201462036-MapReduce-YARN-Memory-Parameters)的一张图，整合上述几个参数。

![Copy_of_Yarn_mem_params.jpg](../../img/Copy_of_Yarn_mem_params.jpg)

RM每次分配给container的最小内存为1GB，AM会将每次申请的内存大小（`mapreduce.map/reduce.memory.mb`）进行调整，每次调整的内存大小为`yarn.scheduler.increment-allocation-mb`（在Fair Scheduler中，该值默认为512MB）* n+`mapreduce.map/reduce.memory.mb`，即若map container设置的内存（`mapreduce.map.memory.mb`）为1001MB，AM将从RM申请1GB+512MB=1.5GB，若map container申请的内存为1.G，AM将向RM申请1GB+512MB*2=2G。






## Reference
- [MapReduce YARN Memory Parameters](https://support.pivotal.io/hc/en-us/articles/201462036-MapReduce-YARN-Memory-Parameters)
