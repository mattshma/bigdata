依次对如下方面说下Yarn的调优：
- ResourceManager
- NodeManager
- ApplicationMaster
- vcore
- Container


Configuring YARN Settings
---

- mapreduce.map.memory.mb

默认为1G，这里调整为2G。

- mapreduce.reduce.memory.mb

默认为1G，调整为`mapreduce.map.memory.mb`的2倍，即4G。

- mapreduce.map.java.opts.max.heap

0.8 * mapreduce.map.memory.mb

- mapreduce.reduce.java.opts.max.heap

0.8 * mapreduce.reduce.java.opts.max.heap

- Java Heap Size of NodeManager in Bytes
4G

- Java Heap Size of ResourceManager in Bytes
8G

- yarn.nodemanager.resource.memory-mb
40G --> 50G

- yarn.nodemanager.resource.cpu-vcores
24 --> 20

- mapreduce.task.io.sort.mb
256M --> 1GB

- mapreduce.task.io.sort.factor
64 --> 100

- mapreduce.reduce.shuffle.parallelcopies
10 --> 50

- mapreduce.job.ubertask.enable
true

- mapreduce.job.ubertask.maxbytes
无 --> 64M

HDFS
---

- Java Heap Size of Namenode in Bytes
13565MB --> 8gb

- Java Heap Size of Secondary namenode in Bytes
13565MB --> 8gb




### 参考
- [Yarn Overview](http://hadoop.apache.org/docs/current/hadoop-yarn/hadoop-yarn-site/YARN.html)
- [Tuning the Cluster for MapReduce v2 (YARN)](http://www.cloudera.com/content/cloudera/en/documentation/core/latest/topics/cdh_ig_yarn_tuning.html)

