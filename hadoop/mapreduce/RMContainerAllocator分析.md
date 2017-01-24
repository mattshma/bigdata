# RMContainerAllocator分析
__说明：Hadoop版本为2.6.0。为减少代码量，文中代码多做过删减，完整代码需参考官方源码。__

## 背景
业务方Job正常情况1个小时能执行完成，但在某些时候，会执行4个多小时甚至失败。查看失败的Log，发现有如下报警：

```
2017-01-21 20:41:15,315 INFO org.apache.hadoop.yarn.server.nodemanager.containermanager.ContainerManagerImpl: Start request for container_e75_1484634387643_2389_01_025965 by user dba
2017-01-21 20:41:15,315 INFO org.apache.hadoop.yarn.server.nodemanager.NMAuditLogger: USER=dba  IP=10.5.32.164  OPERATION=Start Container Request       TARGET=ContainerManageImpl      RESULT=SUCCESS  APPID=application_1484634387643_2389    CONTAINERID=container_e75_1484634387643_2389_01_025965
2017-01-21 20:41:15,315 INFO org.apache.hadoop.yarn.server.nodemanager.containermanager.application.Application: Adding container_e75_1484634387643_2389_01_025965 to application application_1484634387643_2389
2017-01-21 20:41:15,316 INFO org.apache.hadoop.yarn.server.nodemanager.containermanager.container.Container: Container container_e75_1484634387643_2389_01_025965 transitioned from NEW to LOCALIZING
2017-01-21 20:41:15,316 INFO org.apache.spark.network.yarn.YarnShuffleService: Initializing container container_e75_1484634387643_2389_01_025965
2017-01-21 20:41:15,317 INFO org.apache.hadoop.yarn.server.nodemanager.containermanager.container.Container: Container container_e75_1484634387643_2389_01_025965 transitioned from LOCALIZING to LOCALIZED
2017-01-21 20:41:15,339 INFO org.apache.hadoop.yarn.server.nodemanager.containermanager.container.Container: Container container_e75_1484634387643_2389_01_025965 transitioned from LOCALIZED to RUNNING
2017-01-21 20:41:15,343 INFO org.apache.hadoop.yarn.server.nodemanager.DefaultContainerExecutor: launchContainer: [bash, /hadoop10/yarn/nm/usercache/dba/appcache/application_1484634387643_2389/container_e75_1484634387643_2389_01_025965/default_container_executor.sh]
2017-01-21 20:41:15,832 INFO org.apache.hadoop.yarn.server.nodemanager.containermanager.monitor.ContainersMonitorImpl: Starting resource-monitoring for container_e75_1484634387643_2389_01_025965
2017-01-21 20:41:16,109 INFO org.apache.hadoop.yarn.server.nodemanager.containermanager.monitor.ContainersMonitorImpl: Memory usage of ProcessTree 12818 for container-id container_e75_1484634387643_2389_01_025965: 87.5 MB of 4 GB physical memory used; 4.0 GB of 8.4 GB virtual memory used
...
2017-01-21 21:39:16,262 INFO org.apache.hadoop.yarn.server.nodemanager.containermanager.monitor.ContainersMonitorImpl: Memory usage of ProcessTree 12818 for container-id container_e75_1484634387643_2389_01_025965: 696.2 MB of 4 GB physical memory used; 4.1 GB of 8.4 GB virtual memory used
2017-01-21 21:39:17,734 INFO org.apache.hadoop.yarn.server.nodemanager.containermanager.launcher.ContainerLaunch: Cleaning up container container_e75_1484634387643_2389_01_025965
2017-01-21 21:39:17,675 INFO org.apache.hadoop.yarn.server.nodemanager.containermanager.ContainerManagerImpl: Stopping container with container Id: container_e75_1484634387643_2389_01_025965
2017-01-21 21:39:17,676 INFO org.apache.hadoop.yarn.server.nodemanager.NMAuditLogger: USER=dba  IP=10.5.32.164  OPERATION=Stop Container Request        TARGET=ContainerManageImpl      RESULT=SUCCESS  APPID=application_1484634387643_2389    CONTAINERID=container_e75_1484634387643_2389_01_025965
2017-01-21 21:39:17,678 INFO org.apache.hadoop.yarn.server.nodemanager.containermanager.container.Container: Container container_e75_1484634387643_2389_01_025965 transitioned from RUNNING to KILLING
2017-01-21 21:39:17,734 INFO org.apache.hadoop.yarn.server.nodemanager.containermanager.launcher.ContainerLaunch: Cleaning up container container_e75_1484634387643_2389_01_025965
2017-01-21 21:39:17,746 WARN org.apache.hadoop.yarn.server.nodemanager.DefaultContainerExecutor: Exit code from container container_e75_1484634387643_2389_01_025965 is : 143
2017-01-21 21:39:17,758 INFO org.apache.hadoop.yarn.server.nodemanager.containermanager.container.Container: Container container_e75_1484634387643_2389_01_025965 transitioned from KILLING to CONTAINER_CLEANEDUP_AFTER_KILL
2017-01-21 21:39:17,787 INFO org.apache.hadoop.yarn.server.nodemanager.DefaultContainerExecutor: Deleting absolute path : /hadoop/yarn/nm/usercache/dba/appcache/application_1484634387643_2389/container_e75_1484634387643_2389_01_025965
2017-01-21 21:39:17,789 INFO org.apache.hadoop.yarn.server.nodemanager.NMAuditLogger: USER=dba  OPERATION=Container Finished - Killed   TARGET=ContainerImpl    RESULT=SUCCESS  APPID=application_1484634387643_2389    CONTAINERID=container_e75_1484634387643_2389_01_025965
2017-01-21 21:39:17,789 INFO org.apache.hadoop.yarn.server.nodemanager.containermanager.container.Container: Container container_e75_1484634387643_2389_01_025965 transitioned from CONTAINER_CLEANEDUP_AFTER_KILL to DONE
2017-01-21 21:39:17,791 INFO org.apache.hadoop.yarn.server.nodemanager.containermanager.application.Application: Removing container_e75_1484634387643_2389_01_025965 from application application_1484634387643_2389
2017-01-21 21:39:17,791 INFO org.apache.hadoop.yarn.server.nodemanager.containermanager.logaggregation.AppLogAggregatorImpl: Considering container container_e75_1484634387643_2389_01_025965 for log-aggregation
2017-01-21 21:39:17,791 INFO org.apache.hadoop.yarn.server.nodemanager.containermanager.AuxServices: Got event CONTAINER_STOP for appId application_1484634387643_2389
2017-01-21 21:39:17,791 INFO org.apache.spark.network.yarn.YarnShuffleService: Stopping container container_e75_1484634387643_2389_01_025965
```

而Yarn JobHistory UI上Note项显示：`Reducer preempted to make room for pending map attempts`和`Task KILL is received. Killing attempt!`。

从实际监控来看，出现问题时，没跑完的map全在pending状态，而reduce在copy阶段已占用大量资源，由于map一直在等空闲资源，而reduce一直等未完成的map执行完，形成了一个死锁。大约一个多小时后，AppMaster将reduce kill并释放资源。出现这种情况时，Job运行时间会增加几小时。

## ContainerAllocator介绍
ContainerAllocator通过与RM通信，为Job申请资源。

在[注释](https://github.com/apache/hadoop/blob/branch-2.6.0/hadoop-mapreduce-project/hadoop-mapreduce-client/hadoop-mapreduce-client-app/src/main/java/org/apache/hadoop/mapreduce/v2/app/rm/RMContainerAllocator.java#L120)中可以看到，map生命周期为`scheduled->assigned->completed`，reduce生命周期为`pending->scheduled->assigned->completed`。只要收到map的请求后，map的状态即变为`scheduled`状态，reduce根据map完成数和集群资源情况在`pending`和`scheduled`状态中变动。

> Vocabulary Used: 
> pending -> requests which are NOT yet sent to RM
> scheduled -> requests which are sent to RM but not yet assigned
> assigned -> requests which are assigned to a container
> completed -> request corresponding to which container has completed 

ContainerAllocator将所有任务分成三类：
- Failed Map。Priority为5。
- Reduce。Priority为10。
- Map。Priority为20。
Priority越低，该任务优先级越高。即这三种任务同时请求资源时，若有充足资源，会优先分配给Failed Map，其次是Reduce，最后才是Map。

## 源码分析

在MRAppMaster类的[serviceStart()](https://github.com/apache/hadoop/blob/branch-2.6.0/hadoop-mapreduce-project/hadoop-mapreduce-client/hadoop-mapreduce-client-app/src/main/java/org/apache/hadoop/mapreduce/v2/app/MRAppMaster.java#L808)方法中，可以看到其会启动RMContainerAllocator的`init()`方法和`start()`方法：

```
      ((Service)this.containerAllocator).init(getConfig());
      ((Service)this.containerAllocator).start();
```
由于MRAppMaster继承自CompositeService类，CompositeService类继承自抽象类AbstractService。在AbstractService类的[init()](https://github.com/apache/hadoop/blob/branch-2.6.0/hadoop-common-project/hadoop-common/src/main/java/org/apache/hadoop/service/AbstractService.java#L151)会调用`serviceInit()`方法，[start()](serviceInit)调用`serviceStart()`方法，所以这两行最终调用RMContainerAllocator类的`serviceInit()`和`serviceStart()`方法。下面依次讨论。

[serviceInit()](https://github.com/apache/hadoop/blob/branch-2.6.0/hadoop-mapreduce-project/hadoop-mapreduce-client/hadoop-mapreduce-client-app/src/main/java/org/apache/hadoop/mapreduce/v2/app/rm/RMContainerAllocator.java#L183)方法如下：

```
  @Override
  protected void serviceInit(Configuration conf) throws Exception {
    super.serviceInit(conf);
    reduceSlowStart = conf.getFloat(
        MRJobConfig.COMPLETED_MAPS_FOR_REDUCE_SLOWSTART, 
        DEFAULT_COMPLETED_MAPS_PERCENT_FOR_REDUCE_SLOWSTART);
    maxReduceRampupLimit = conf.getFloat(
        MRJobConfig.MR_AM_JOB_REDUCE_RAMPUP_UP_LIMIT, 
        MRJobConfig.DEFAULT_MR_AM_JOB_REDUCE_RAMP_UP_LIMIT);
    maxReducePreemptionLimit = conf.getFloat(
        MRJobConfig.MR_AM_JOB_REDUCE_PREEMPTION_LIMIT,
        MRJobConfig.DEFAULT_MR_AM_JOB_REDUCE_PREEMPTION_LIMIT);
    allocationDelayThresholdMs = conf.getInt(
        MRJobConfig.MR_JOB_REDUCER_PREEMPT_DELAY_SEC,
        MRJobConfig.DEFAULT_MR_JOB_REDUCER_PREEMPT_DELAY_SEC) * 1000;//sec -> ms
    RackResolver.init(conf);
    retryInterval = getConfig().getLong(MRJobConfig.MR_AM_TO_RM_WAIT_INTERVAL_MS,
                                MRJobConfig.DEFAULT_MR_AM_TO_RM_WAIT_INTERVAL_MS);
    // Init startTime to current time. If all goes well, it will be reset after
    // first attempt to contact RM.
    retrystartTime = System.currentTimeMillis();
  }
```
其会设置部分参数，这里将这个参数进行说明，因为这部分参数会影响MapReduce的行为。查看[MRJobConfig类](https://github.com/apache/hadoop/blob/branch-2.6.0/hadoop-mapreduce-project/hadoop-mapreduce-client/hadoop-mapreduce-client-core/src/main/java/org/apache/hadoop/mapreduce/MRJobConfig.java)和[mapred-default.xml](https://github.com/apache/hadoop/blob/branch-2.6.0/hadoop-mapreduce-project/hadoop-mapreduce-client/hadoop-mapreduce-client-core/src/main/resources/mapred-default.xml)，各变量由配置文件如下参数设置：

  变量名  |  配置文件  |  说明
----------|------------|----------
COMPLETED_MAPS_FOR_REDUCE_SLOWSTART | mapreduce.job.reduce.slowstart.completedmaps | 完成的map比例达到该值才开始执行reduce任务，默认为0.05，即5%。
DEFAULT_COMPLETED_MAPS_PERCENT_FOR_REDUCE_SLOWSTART | 0.05f | 
MR_AM_JOB_REDUCE_RAMPUP_UP_LIMIT | yarn.app.mapreduce.am.job.reduce.rampup.limit | 在map任务完成前，最多启动reduce任务的比例。
DEFAULT_MR_AM_JOB_REDUCE_RAMP_UP_LIMIT | 0.5f | 
MR_AM_JOB_REDUCE_PREEMPTION_LIMIT | yarn.app.mapreduce.am.job.reduce.preemption.limit | map任务最多可抢占的reduce任务的比例。
DEFAULT_MR_AM_JOB_REDUCE_PREEMPTION_LIMIT | 0.5f | 
MR_JOB_REDUCER_PREEMPT_DELAY_SEC | mapreduce.job.reducer.preempt.delay.sec | 当map请求资源不足时，多久抢占reduce的资源。默认为0，即只要map资源不足即抢占reduce资源。
DEFAULT_MR_JOB_REDUCER_PREEMPT_DELAY_SEC | 0 | 
MR_AM_TO_RM_WAIT_INTERVAL_MS | yarn.app.mapreduce.am.scheduler.connection.wait.interval-ms | AM和RM的连接丢失后，AM等待多久才会aborting，在这段时间内，AM会一直尝试连接RM。
DEFAULT_MR_AM_TO_RM_WAIT_INTERVAL_MS | 360000 | 

接着看`servcieStart()`方法，其会调用父类RMCommunicator(RMContainerAllocator继承自RMContainerRequestor继承自RMCommunicator)的`serviceStart()`，此时会调用`startAllocatorThread()`，该方法又会启动RMContainerAllocator类的`heartbeat()`，对于类RMContainerAllocator，`heartbeat()`是一个非常重要的类。其周期性的向RM发送心跳，告知自己状态，并获取分配的资源的Container的运行状态，如下：

```
protected synchronized void heartbeat() throws Exception {
    List<Container> allocatedContainers = getResources();
    if (allocatedContainers != null && allocatedContainers.size() > 0) {
      scheduledRequests.assign(allocatedContainers);
    }

    int completedMaps = getJob().getCompletedMaps();
    int completedTasks = completedMaps + getJob().getCompletedReduces();

    // 如果还有Task未执行完，则调用preemptReducesIfNeeded()方法。
    if ((lastCompletedTasks != completedTasks) ||
          (scheduledRequests.maps.size() > 0)) {
      lastCompletedTasks = completedTasks;
      recalculateReduceSchedule = true;
    }

    if (recalculateReduceSchedule) {
      preemptReducesIfNeeded();
      scheduleReduces(
          getJob().getTotalMaps(), completedMaps,
          scheduledRequests.maps.size(), scheduledRequests.reduces.size(), 
          assignedRequests.maps.size(), assignedRequests.reduces.size(),
          mapResourceRequest, reduceResourceRequest,
          pendingReduces.size(), 
          maxReduceRampupLimit, reduceSlowStart);
      recalculateReduceSchedule = false;
    }
```

接着看[preemptReducesIfNeeded](https://github.com/apache/hadoop/blob/branch-2.6.0/hadoop-mapreduce-project/hadoop-mapreduce-client/hadoop-mapreduce-client-app/src/main/java/org/apache/hadoop/mapreduce/v2/app/rm/RMContainerAllocator.java#L446):
```
 void preemptReducesIfNeeded() {
    .....
    //如果有unassigned的map，检查reduce是否占满了集群资源。
    if (scheduledRequests.maps.size() > 0) {
      Resource resourceLimit = getResourceLimit();
      Resource availableResourceForMap =
          Resources.subtract(
            resourceLimit,
            Resources.multiply(reduceResourceRequest,
              assignedRequests.reduces.size()
                  - assignedRequests.preemptionWaitingReduces.size()));
      //保证可用的内存至少能满足一个map的请求
      if (ResourceCalculatorUtils.computeAvailableContainers(availableResourceForMap,
        mapResourceRequest, getSchedulerResourceTypes()) <= 0) {
        // 保证新分配的container分配给map，并将scheduledRequest中的所有scheduled状态的reduce转变pending状态。（因为reduce任务优先级高于map任务）
        for (ContainerRequest req : scheduledRequests.reduces.values()) {
          pendingReduces.add(req);
        }
        scheduledRequests.reduces.clear();
 
        //do further checking to find the number of map requests that were
        //hanging around for a while
        int hangingMapRequests = getNumOfHangingRequests(scheduledRequests.maps);
        if (hangingMapRequests > 0) {
          // 为运行一个map需要抢占的reduce数。
          int preemptionReduceNumForOneMap =
              ResourceCalculatorUtils.divideAndCeilContainers(mapResourceRequest,
                reduceResourceRequest, getSchedulerResourceTypes());
	  // 最多允许抢占的Reduce数。
          int preemptionReduceNumForPreemptionLimit =
              ResourceCalculatorUtils.divideAndCeilContainers(
                Resources.multiply(resourceLimit, maxReducePreemptionLimit),
                reduceResourceRequest, getSchedulerResourceTypes());
	  //为运行所有hanging的map需要抢占的reduce数。
          int preemptionReduceNumForAllMaps =
              ResourceCalculatorUtils.divideAndCeilContainers(
                Resources.multiply(mapResourceRequest, hangingMapRequests),
                reduceResourceRequest, getSchedulerResourceTypes());
          int toPreempt =
              Math.min(Math.max(preemptionReduceNumForOneMap,
                preemptionReduceNumForPreemptionLimit),
                preemptionReduceNumForAllMaps);

          assignedRequests.preemptReduce(toPreempt);
        }
      }
    }
  }
```

最后看[preemptReduce()](https://github.com/apache/hadoop/blob/branch-2.6.0/hadoop-mapreduce-project/hadoop-mapreduce-client/hadoop-mapreduce-client-app/src/main/java/org/apache/hadoop/mapreduce/v2/app/rm/RMContainerAllocator.java#L1270)方法：
```
    void preemptReduce(int toPreempt) {
      List<TaskAttemptId> reduceList = new ArrayList<TaskAttemptId>(reduces.keySet());
      Collections.sort(reduceList,
          new Comparator<TaskAttemptId>() {
        @Override
        public int compare(TaskAttemptId o1, TaskAttemptId o2) {
          return Float.compare(
              getJob().getTask(o1.getTaskId()).getAttempt(o1).getProgress(),
              getJob().getTask(o2.getTaskId()).getAttempt(o2).getProgress());
        }
      });
      // Kill Reduce。
      for (int i = 0; i < toPreempt && reduceList.size() > 0; i++) {
        TaskAttemptId id = reduceList.remove(0);//remove the one on top
        preemptionWaitingReduces.add(id);
        // RAMPDOWN_DIAGNOSTIC = "Reducer preempted to make room for pending map attempts"
        eventHandler.handle(new TaskAttemptKillEvent(id, RAMPDOWN_DIAGNOSTIC));
      }
    }
```

至此整个问题已大致清楚。
