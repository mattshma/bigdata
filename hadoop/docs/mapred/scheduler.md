MRv1 Scheduler
===

这里介绍下MRv1资源调度器的一些情况。原始MRv1的资源调度器是FIFO，其只能等前面所以Job执行完才能执行后面的Job。目前有两种可以选择的调度器:

- [Fair Scheduler](https://hadoop.apache.org/docs/r1.2.1/fair_scheduler.html)
- [Capacity Scheduler](https://hadoop.apache.org/docs/r1.2.1/capacity_scheduler.html)

在 issue 中还介绍了两种新的调度器：

- [Adaptive Scheduler](https://issues.apache.org/jira/browse/MAPREDUCE-1380)
- [Learning Scheduler](https://issues.apache.org/jira/browse/MAPREDUCE-1439)

这里先介绍下Capacity Scheduler。

Capacity Scheduler
---
Capacity Scheduler 提供多个 queue，Job都提交给queue。每个 queue 占用一部分系统资源，所以提交到queue的job都有权限使用queue。

### Features
- 系统管理员可以设置软限制和可选的硬限制来限制每个queue。
- 每个queue都有一个严格的 ACLs 列表来控制用户是否可以访问使用。同时有safe-guard来保证用户不能查看/修改其他用户的job。每个queue都可以设置管理员权限。
- 空闲资源能被分配给任何超出容量的queue。当queue中任务请求容量大于queue限制时，该queue上的任务会被指定给有剩余容量的queue上的job去执行。这能最大化的利用集群资源。
- 一些限制能防止单个job，用户，queue耗尽系统资源。
- 一些设置可以job运行时配置，而且管理员和用户可以在终端中查看queue资源的分配情况。
- 支持资源密集型job。可以指定超出默认设置更多的资源用来满足不同资源要求的job。目前只支持内存密集型job。
- queue可支持不同优先级的job（默认不支持），在一个queue中，优先级高的job比优先级低的job更先获得资源。然后，一旦job运行起来，即使后来的job优先级再高其也不会先占其资源。

Fair Scheduler
---

Fair Scheduler是一种随着时间推移，所有job仍能获取同等共享资源的调度方法。当集群中仅有一个job运行时，这个job会占用集群所有资源；当有新job提交时，部分任务槽(task slot)会被腾出来分配给新的job，以使每个job都能获取大概相等的cpu时间片。Fair Scheduler 将job放入 pool 中，每个pool拥有相同的系统资源。默认情况下，每个用户有各自独立的pool。可以按照用户的unix级或job配置属性来设置job的pool。在每个pool内部，可以使用公平共享或先进先出（FIFO）来调度job。

### Features

- 支持job优先级。优先级越高的job，获取的资源越多。
- 每个pool可以配置最小配额的共享资源。即pool中的每个job至少会有最小配额资源。如果每个job已占有最小配额资源，此时pool还有多余资源的话，多余资源会被其他pool分掉。而如果pool中的资源不足以满足当前job的最小配额资源，调度器支持占用其他pool中job的资源，该pool被允许关掉其他pool中的任务（task），以腾出空间给当前job用。优先抢占其他pool资源有利于生产环境的job不会被同时运行在集群上的测试或研究用的job占用过多资源。当选择kill任务（task）时，Fair Scheduler会将超额job最近刚运行的task关掉，以最小化浪费机器资源。被占用资源的job不会失败，其只会延长job完成时间，因为hadoop job容忍丢失任务(task)。
- 能限制每个pool每个用户并发运行的job数。
- 能限制每个pool并发运行的task数

### ACLs

Fair Scheduler 能和 Queue 联合起来做acl控制，这实现这样的功能，首先开启ACLs并如[MapReduce usage guide](https://hadoop.apache.org/docs/r1.2.1/mapred_tutorial.html#Job+Authorization)所述设置一些queue。接着给每个queue的pool设置如下属性(mapred-site.xml)：

```
<property>
  <name>mapred.fairscheduler.poolnameproperty</name>
  <value>mapred.job.queue.name</value>
</property>
```

参考
---
- [Apache Capacity Scheduler Guide](https://hadoop.apache.org/docs/r1.2.1/capacity_scheduler.html)
- [Cloudera Capacity Scheduler Guide](http://archive.cloudera.com/cdh/3/hadoop/capacity_scheduler.html)
- [Apache Fair Scheduler](https://hadoop.apache.org/docs/r1.2.1/fair_scheduler.html)
- [Cloudera Fair Scheduler](http://archive.cloudera.com/cdh/3/hadoop/fair_scheduler.html)
- [MapReduce Tutorial](https://hadoop.apache.org/docs/r1.2.1/mapred_tutorial.html#Job+Authorization)
- [Hadoop Fair Scheduler Design Document](https://issues.apache.org/jira/secure/attachment/12457515/fair_scheduler_design_doc.pdf)
- [How to: Job Execution Framework MapReduce V1 & V2](https://www.mapr.com/blog/how-job-execution-framework-mapreduce-v1-v2#.VUcboq2qqko)

