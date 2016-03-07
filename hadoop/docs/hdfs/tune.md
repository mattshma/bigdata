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

## vcore
vcore的调整基本同内存。nodemanager能分配的总的vcore数为`yarn.nodemanager.resource.cpu-vcores`，每个container分配的最大vcore数为`yarn.scheduler.maximum-allocation-vcores`，最小vcore数为`yarn.scheduler.minimum-allocation-vcores`，AM的调整因子为`yarn.scheduler.increment-allocation-vcores`，在Fair Scheduler中该值默认为1。map或reduce任务每次使用的vcore数为`mapreduce.map/reduce.cpu.vcores`。而AM使用vcore为`yarn.app.mapreduce.am.resource.cpu-vcores`。

## scheduler

一般情况下，各任务根据scheduler的设置运行在相应的queue中，因此，queue的设置也相当重要。这部分的设置和业务比较紧密，因此这里暂不赘述。

## shuffle
shuffle做为MR奇迹发生的地方，优化好的话能很大程序提高job的运行速度。shuffle的具体过程可参考[这里](http://langyu.iteye.com/blog/992916)。总得来说应该多给shuffle分配资源，但同时也应确保map和reduce运行正常。优化分为两方面：1)减少磁盘读写次数；2)减少磁盘读写量。

对于前者来言，在map端，可调大`mapreduce.task.io.sort.mb`的值，减少spill次数；在reduce端的shuffle过程中，a).可调大`mapreduce.reduce.shuffle.input.buffer.percent`（占`mapreduce.reduce.java.opts`的比例）的值，以分配更多内存给reduce端的shuffle接收map端的数据。b). 当reduce端copy阶段的内存达到`mapred.job.shuffle.merge.percent`或map输出结果个数达到`mapreduce.reduce.merge.inmem.threshold`时，即做merge操作，一般而言，可将`mapreduce.reduce.merge.inmem.threshold`调整为0来做优化。c). 另外，若reduce函数需求内存不是很多，可提高`mapreduce.reduce.input.buffer.percent`的值来缓存部分merge合并数据给reduce以减小磁盘读写次数。

对于后者，可将map的中间结果和最终的输出结果进行压缩。对map的中间结果压缩，需设置`mapreduce.map.output.compress`为`True`，并指定`mapreduce.map.output.compress.codec`为需要的编码解码器。对最终结果压缩，需设置`mapreduce.output.fileoutputformat.compress`为`True`，并设置`mapreduce.output.fileoutputformat.compress.codec `为需要的codec，若最终输出会写到SequenceFiles，还可设置`mapreduce.output.fileoutputformat.compress.type`为`BLOCK`来提高性能。

另外`mapreduce.reduce.shuffle.parallelcopies`定义了reduce并发copy map输出的线程个数，当map数较多时，可适当提高该值来提高copy速度。

## 其他调整
### Uber
在MR1中有JVM重用的概念，在YARN中，相应的概念为Uber，对于小任务，Uber会省掉申请和退出JVM的次数，以提高Job执行次数。默认情况下YARN禁用Uber，此时AM会对job的每一个task都申请一个container，task执行完，该container会被回收。开启uber后，"小job"的所有task都在一个jvm运行。开启uber的参数为`mapreduce.job.ubertask.enable`，"小job"的定义为`mapreduce.job.ubertask.maxmaps`（默认为9），`mapreduce.job.ubertask.maxreduces`（默认为1，当前版本不支持reduce数大于1的情况），`mapreduce.job.ubertask.maxbytes`（默认为空）。

### 缓冲区大小
hadoop默认使用4KB的缓冲区辅助I/O操作，对于现在操作系统和硬件而言，这个值太过保守，增长缓冲区大小可显著提高性能，如128KB（131 072字节）更为常见。可通过core-site.xml中的`io.file.buffer.size`来进行设置。

### HDFS块大小
默认情况下HDFS的块大小为64MB，可调大该值为256MB来降低namenode的内存压力。参数为`dfs.blocksize`。在HADOOP2.7中，该值已默认为128MB。

### split块大小
block是物理块，split是逻辑块。一个split对应一个map输入。split的个数由`Math.max(minSize, Math.min(goalSize, blockSize))`决定，其中minSize由`mapreduce.input.fileinputformat.split.minsize`设置，默认为0；goalSize由`goalSize = totalSize / (numSplits == 0 ? 1 : numSplits)`得到，即文件大小除以用户设置的map数，若未设置map数，则默认为1；blockSize即为block大小。若多于一半的job其mapper运行时间都小于1分钟，可以考虑调高`mapreduce.input.fileinputformat.split.minsize`的值。


### Short Circuit Local Reads
一般而言，Hadoop尽量将计算放在拥有数据的节点上，这使得数据和计算经常在一个节点上，形成大量的Local Reads 以影响网络传输。一般客户端读写数据的过程是先从datanode读取，然后再通过RPC把数据传输给DFSClient。若数据和读取端都在一个节点上，这样的过程虽然简单，但性能会有些影响，因为需要在datanode做一次中转。client直接读完文件的过程即所谓的"short-circuit"。

[HDFS-2246](https://issues.apache.org/jira/browse/HDFS-2246)和[HDFS-347](https://issues.apache.org/jira/browse/HDFS-347)提供两种短路读的方式。从配置复杂性和安全性角度讲，HDFS-2246中的方案都不太合适，因此一般主要使用HDFS-347的Unix Domain Socket方案。

配置Unix Domain Socket需要`libhadoop.so`，可通过`hadoop checknative`查看其是否已安装。short-circuit相关参数为`dfs.client.read.shortcircuit`和`dfs.domain.socket.path`。

## spark




## Reference
- [MapReduce YARN Memory Parameters](https://support.pivotal.io/hc/en-us/articles/201462036-MapReduce-YARN-Memory-Parameters)
- [mapred-default.xml](https://hadoop.apache.org/docs/stable/hadoop-mapreduce-client/hadoop-mapreduce-client-core/mapred-default.xml)
- [HDFS Short-Circuit Local Reads](https://hadoop.apache.org/docs/r2.7.1/hadoop-project-dist/hadoop-hdfs/ShortCircuitLocalReads.html)
