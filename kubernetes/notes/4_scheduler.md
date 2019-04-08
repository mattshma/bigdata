# scheduler

## 简介
我们知道，Kubernetes 的调度分为两个阶段：
- predicate      
  过滤不满足条件的节点。
- priority     
  对满足条件的节点按规则打分，从中选出最符合条件的节点。

predicate 阶段有一系列的算法可以使用，如：
- PodFitsResources          
  节点上剩余的资源是否大于 pod 请求的资源。
- PodFitsHost     
  若 pod 指定了 NodeName，则检查节点名称是否和 NodeName 匹配。
- PodSelectorMatches       
  过滤和指定的 Label 不匹配的节点
- ...

如果 predicate 过程没有合适的节点，pod 会一直处于 `pending` 状态，如果有多个节点满足条件，则进入 prority 阶段，按照优先级大小对节点排序。优先级由一系列 key-value 组成，key 是该优先级的名称，value 是它的权重。如下是一些常用的优先级函数：
- LeastRequestedPriority     
  通过计算 cpu 和 memory 的使用率来决定权重，使用率越低权重越高，即优先分配使用率的节点。
- BalancedResourceAllocation       
  尽量选择在部署 pod 后各资源使用率更均衡的节点，该条件不能单独使用，必须和 LeastRequestedPriority 同时使用。 
- NodeAffinityPriority     
  节点亲和性机制。支持多种操作符。具体可参见节点亲和性方面的文章。
- ImageLocalityPriority      
  判断宿主机上是否存储 pod 需要的镜像，根据镜像情况返回 0-10 的打分，如不存在 pod 需要的镜像，则打零分，存在部分镜像，则需要镜像大小来决定分值，镜像越大，分数越高。


## 代码分析
依然从 cmd 模块着手，查看[cmd/kube-scheduler/scheduler.go](https://github.com/kubernetes/kubernetes/blob/release-1.13/cmd/kube-scheduler/scheduler.go#L37)，其配置的 `runCommand()` 返回 [Run()](https://github.com/kubernetes/kubernetes/blob/release-1.13/cmd/kube-scheduler/app/server.go#L167) ，如下：
```
// Run executes the scheduler based on the given configuration. It only return on error or when stopCh is closed.
func Run(cc schedulerserverconfig.CompletedConfig, stopCh <-chan struct{}) error {
var storageClassInformer storageinformers.StorageClassInformer
	if utilfeature.DefaultFeatureGate.Enabled(features.VolumeScheduling) {
		storageClassInformer = cc.InformerFactory.Storage().V1().StorageClasses()
	}

	// Create the scheduler.
	sched, err := scheduler.New(cc.Client,
		cc.InformerFactory.Core().V1().Nodes(),
		cc.PodInformer,
		cc.InformerFactory.Core().V1().PersistentVolumes(),
		cc.InformerFactory.Core().V1().PersistentVolumeClaims(),
		cc.InformerFactory.Core().V1().ReplicationControllers(),
		cc.InformerFactory.Apps().V1().ReplicaSets(),
		cc.InformerFactory.Apps().V1().StatefulSets(),
		cc.InformerFactory.Core().V1().Services(),
		cc.InformerFactory.Policy().V1beta1().PodDisruptionBudgets(),
		storageClassInformer,
		cc.Recorder,
		cc.ComponentConfig.AlgorithmSource,
		stopCh,
		scheduler.WithName(cc.ComponentConfig.SchedulerName),      // 设置调度器 name，默认为 default-scheduler
		scheduler.WithHardPodAffinitySymmetricWeight(cc.ComponentConfig.HardPodAffinitySymmetricWeight),  // 设置 hardPodAffinitySymmetricWeight 值，默认为 1
		scheduler.WithEquivalenceClassCacheEnabled(cc.ComponentConfig.EnableContentionProfiling),  // 设置 enableEquivalenceClassCache 值，默认为 false
		scheduler.WithPreemptionDisabled(cc.ComponentConfig.DisablePreemption),  // 设置 disablePreemption 值，默认为 false
		scheduler.WithPercentageOfNodesToScore(cc.ComponentConfig.PercentageOfNodesToScore),  // 设置 percentageOfNodesToScore 值，默认为 50	
		scheduler.WithBindTimeoutSeconds(*cc.ComponentConfig.BindTimeoutSeconds))  // 设置 bindTimeoutSeconds 值，默认为 100
	if err != nil {
		return err
	}

	// Prepare the event broadcaster.
	// 将从 EventBroadcaster 中收到的 event，发送给指定的 sink
	if cc.Broadcaster != nil && cc.EventClient != nil {
		cc.Broadcaster.StartRecordingToSink(&v1core.EventSinkImpl{Interface: cc.EventClient.Events("")})
	}

	// Setup healthz checks.
	var checks []healthz.HealthzChecker
	if cc.ComponentConfig.LeaderElection.LeaderElect {
		checks = append(checks, cc.LeaderElection.WatchDog)
	}

	// Start up the healthz server.
	if cc.InsecureServing != nil {
		separateMetrics := cc.InsecureMetricsServing != nil
		handler := buildHandlerChain(newHealthzHandler(&cc.ComponentConfig, separateMetrics, checks...), nil, nil)
		if err := cc.InsecureServing.Serve(handler, 0, stopCh); err != nil {
			return fmt.Errorf("failed to start healthz server: %v", err)
		}
	}
	if cc.InsecureMetricsServing != nil {
		handler := buildHandlerChain(newMetricsHandler(&cc.ComponentConfig), nil, nil)
		if err := cc.InsecureMetricsServing.Serve(handler, 0, stopCh); err != nil {
			return fmt.Errorf("failed to start metrics server: %v", err)
		}
	}
	if cc.SecureServing != nil {
		handler := buildHandlerChain(newHealthzHandler(&cc.ComponentConfig, false, checks...), cc.Authentication.Authenticator, cc.Authorization.Authorizer)
		if err := cc.SecureServing.Serve(handler, 0, stopCh); err != nil {
			// fail early for secure handlers, removing the old error loop from above
			return fmt.Errorf("failed to start healthz server: %v", err)
		}
	}

	// 启动所有的 informers
	go cc.PodInformer.Informer().Run(stopCh)
	cc.InformerFactory.Start(stopCh)

	// Wait for all caches to sync before scheduling.
	// 调度前等待所有 cache 同步完成。
	cc.InformerFactory.WaitForCacheSync(stopCh)
	controller.WaitForCacheSync("scheduler", stopCh, cc.PodInformer.Informer().HasSynced)

	// Prepare a reusable runCommand function.
	run := func(ctx context.Context) {
		sched.Run()
		<-ctx.Done()
	}

	ctx, cancel := context.WithCancel(context.TODO()) // TODO once Run() accepts a context, it should be used here
	defer cancel()

	go func() {
		select {
		case <-stopCh:
			cancel()
		case <-ctx.Done():
		}
	}()

	// 若设置了选主，则通过 LeaderElector 运行，否则直接运行 run
	if cc.LeaderElection != nil {
		cc.LeaderElection.Callbacks = leaderelection.LeaderCallbacks{
			OnStartedLeading: run,
			OnStoppedLeading: func() {
				utilruntime.HandleError(fmt.Errorf("lost master"))
			},
		}
		leaderElector, err := leaderelection.NewLeaderElector(*cc.LeaderElection)
		if err != nil {
			return fmt.Errorf("couldn't create leader elector: %v", err)
		}

		leaderElector.Run(ctx)

		return fmt.Errorf("lost lease")
	}

	// Leader election is disabled, so runCommand inline until done.
	run(ctx)
	return fmt.Errorf("finished without leader elect")
}
```
如方法的注释所说，`Run` 通过给定的配置执行 scheduler，仅当 stopCh 关闭或出现错误时返回。还有几点可以看到：
1. 启动 schedulerserverconfig.CompletedConfig 相关的所有 Informer，关于 Informer 的内容，会在后面在介绍。
2. 在调度前需等待所有 cache 同步完成。
3. 若配置了 scheduler 的高可用，还会进行选主操作。

可以看到 `run` 方法会调用 [scheduler.go](https://github.com/kubernetes/kubernetes/blob/release-1.13/pkg/scheduler/scheduler.go#L276) 中的`Run()`，如下：
```
// Run begins watching and scheduling. It waits for cache to be synced, then starts a goroutine and returns immediately.
func (sched *Scheduler) Run() {
	if !sched.config.WaitForCacheSync() {
		return
	}

	go wait.Until(sched.scheduleOne, 0, sched.config.StopEverything)
}
```

查看 [scheduleOne()](https://github.com/kubernetes/kubernetes/blob/release-1.13/pkg/scheduler/scheduler.go#L512)，如下：
```
// scheduleOne does the entire scheduling workflow for a single pod.  It is serialized on the scheduling algorithm's host fitting.
func (sched *Scheduler) scheduleOne() {
	pod := sched.config.NextPod()
	...
	// 选取合适的 host
	suggestedHost, err := sched.schedule(pod)
	if err != nil {
		// schedule() may have failed because the pod would not fit on any host, so we try to
		// preempt, with the expectation that the next time the pod is tried for scheduling it
		// will fit due to the preemption. It is also possible that a different pod will schedule
		// into the resources that were preempted, but this is harmless.
		// 如果调度失败，尝试抢占（preempt）
		if fitError, ok := err.(*core.FitError); ok {
			preemptionStartTime := time.Now()
			sched.preempt(pod, fitError)
			...
		} 
		...
		return
	}
	...
	// 如果有合适的 host，则告诉 cache 假设(assume) pod 正运行在给定的节点上，即使当前还未进行绑定（bound）操作，以此减少调度的等待时间。
	assumedPod := pod.DeepCopy()

	// Assume volumes first before assuming the pod.
	//
	// If all volumes are completely bound, then allBound is true and binding will be skipped.
	//
	// Otherwise, binding of volumes is started after the pod is assumed, but before pod binding.
	//
	// This function modifies 'assumedPod' if volume binding is required.
	allBound, err := sched.assumeVolumes(assumedPod, suggestedHost)
	if err != nil {
		klog.Errorf("error assuming volumes: %v", err)
		metrics.PodScheduleErrors.Inc()
		return
	}

	// assume modifies `assumedPod` by setting NodeName=suggestedHost
	err = sched.assume(assumedPod, suggestedHost)
	...
	// bind the pod to its host asynchronously (we can do this b/c of the assumption step above).
	go func() {
		// Bind volumes first before Pod
		if !allBound {
			err := sched.bindVolumes(assumedPod)
			...
		}

		err := sched.bind(assumedPod, &v1.Binding{
			ObjectMeta: metav1.ObjectMeta{Namespace: assumedPod.Namespace, Name: assumedPod.Name, UID: assumedPod.UID},
			Target: v1.ObjectReference{
				Kind: "Node",
				Name: suggestedHost,
			},
		})
		metrics.E2eSchedulingLatency.Observe(metrics.SinceInMicroseconds(start))
	}()
}
```

可以看到，`scheduleOne()` 分为如下几个步骤：
1. 调用 `sched.config.NextPod()` 取出一个 pod。
2. 调用 `sched.schedule(pod)` 为 pod 选择合适的节点。
3. 如果没有合适的节点，将会调用 `sched.preempt()` 开启抢占，进入下一个调度周期。
4. 如果有合适的节点，则调用 `pod.DeepCopy()` 告诉 cache 假设(assume) pod 已运行在给定的节点上了，即使当前还未进行绑定（bound）操作，以此减少调度等待时间，提交效率。
5. 调用 `sched.assumeVolumes()` 执行 assume volume，更新 volume cache。
6. 调用 `sched.assume()`，执行 assume pod。
7. 异步bind，先调用 `sched.bindVolumes()` 执行 bind volumes。再调用 `sched.bind()`，执行 bind pod 。

接下来看下细节，先看第 1 步取 pod，其调用 [getNextPod()](https://github.com/kubernetes/kubernetes/blob/release-1.13/pkg/scheduler/factory/factory.go)，从 [SchedulingQueue](https://github.com/kubernetes/kubernetes/blob/release-1.13/pkg/scheduler/internal/queue/scheduling_queue.go#L60) 队列中取出一个 pod。可以看到，SchedulingQueue 有两种实现方式：
- [FIFO](https://github.com/kubernetes/kubernetes/blob/release-1.13/pkg/scheduler/internal/queue/scheduling_queue.go#L102)
- [PriorityQueue](https://github.com/kubernetes/kubernetes/blob/release-1.13/pkg/scheduler/internal/queue/scheduling_queue.go#L207)   
  PriorityQueue 由两个子队列组成，一个是 `activeQ` ，保存当前需调度的 pod，其是一个 Heap 结构，heap 头上的 pod 是优先级最高的 pod；另一个是 `unschedulableQ`，保存已尝试过并确定不可调度的 pod。

接着看 [schedule()](https://github.com/kubernetes/kubernetes/blob/release-1.13/pkg/scheduler/scheduler.go#L289)，调用了 [sched.config.Algorithm.Schedule()](https://github.com/kubernetes/kubernetes/blob/release-1.13/pkg/scheduler/algorithm/scheduler_interface.go#L79) 进行选 host 的操作。这里看下 ScheduleAlgorithm 接口：
```
type ScheduleAlgorithm interface {
	// 传入 pod，返回合适的节点列表
	Schedule(*v1.Pod, NodeLister) (selectedMachine string, err error)
	// 资源抢占
	Preempt(*v1.Pod, NodeLister, error) (selectedNode *v1.Node, preemptedPods []*v1.Pod, cleanupNominatedPods []*v1.Pod, err error)
	// 预选
	Predicates() map[string]FitPredicate
	// 优选
	Prioritizers() []PriorityConfig
}
```

`ScheduleAlgorithm` 的实现类在 `pkg/scheduler/core/generic_scheduler.go` 中，查看 `schedule()` 过程如下：
- predicate    
    调用 [findNodesThatFit()](https://github.com/kubernetes/kubernetes/blob/release-1.13/pkg/scheduler/core/generic_scheduler.go#L387) ，用于 filter 节点，找出符合条件的节点列表。节点数的[计算方法](https://github.com/kubernetes/kubernetes/blob/release-1.13/pkg/scheduler/core/generic_scheduler.go#L373)如下：
  ```
  func (g *genericScheduler) numFeasibleNodesToFind(numAllNodes int32) int32 {
	if numAllNodes < minFeasibleNodesToFind || g.percentageOfNodesToScore <= 0 ||
		g.percentageOfNodesToScore >= 100 {
		return numAllNodes
	}
	numNodes := numAllNodes * g.percentageOfNodesToScore / 100
	if numNodes < minFeasibleNodesToFind {
		return minFeasibleNodesToFind
	}
	return numNodes
  }
  ```

  然后通过 16 个 worker goroutine 去判断节点是否能满足 pod 的需求。如果配置了 predicate 方法，则使用这些配置的方法，若没配置，则使用默认的 predicate 方法，默认 predicate 如下：
  - NoVolumeZoneConflict: defines the name of predicate NoVolumeZoneConflict
  - MaxEBSVolumeCount: defines the name of predicate MaxEBSVolumeCoun
  - MaxGCEPDVolumeCount: defines the name of predicate MaxGCEPDVolumeCount
  - MaxAzureDiskVolumeCount: defines the name of predicate MaxAzureDiskVolumeCount
  - MaxCSIVolumeCountPred: defines the predicate that decides how many CSI volumes should be attached
  - MatchInterPodAffinity: defines the name of predicate MatchInterPodAffinity
  - NoDiskConflict: defines the name of predicate NoDiskConflict
  - GeneralPredicates: defines the name of predicate GeneralPredicates
  - CheckNodeMemoryPressure: defines the name of predicate CheckNodeMemoryPressure
  - CheckNodeDiskPressure: defines the name of predicate CheckNodeDiskPressure
  - CheckNodePIDPressure: defines the name of predicate CheckNodePIDPressure
  - CheckNodeCondition: defines the name of predicate CheckNodeCondition
  - PodToleratesNodeTaints: defines the name of predicate PodToleratesNodeTaints
  - CheckVolumeBinding: defines the name of predicate CheckVolumeBinding

  然后根据返回的节点列表，进行 priority 筛选。
- priority   
  参考[PrioritizeNodes](https://github.com/kubernetes/kubernetes/blob/release-1.13/pkg/scheduler/core/generic_scheduler.go#L618)，可知每个 priority 函数设置的分数为 0-10 分，这些 priority 函数还有自己的权重，节点的分数为 各priority 分数 * 权重之和。

  默认 priority 如下：
  - SelectorSpreadPriority: spreads pods by minimizing the number of pods (belonging to the same service or replication controller) on the same node
  - InterPodAffinityPriority: pods should be placed in the same topological domain (e.g. same node, same rack, same zone, same power domain, etc.) as some other pods, or, conversely, should not be placed in the same topological domain as some other pods
  - LeastRequestedPriority: Prioritize nodes by least requested utilization
  - BalancedResourceAllocation: Prioritizes nodes to help achieve balanced resource usage
  - NodePreferAvoidPodsPriority: Set this weight large enough to override all other priority functions
  - NodeAffinityPriority: Prioritizes nodes that have labels matching NodeAffinity
  - TaintTolerationPriority: Prioritizes nodes that marked with taint which pod can tolerate
  - ImageLocalityPriority: ImageLocalityPriority prioritizes nodes that have images requested by the pod present

## 参考
- [浅入了解容器编排框架调度器之 Kubernetes](https://zhuanlan.zhihu.com/p/29691157)
- [The Kubernetes Scheduler](https://medium.com/@dominik.tornow/the-kubernetes-scheduler-cd429abac02f)
- [kubernetes 简介：调度器和调度算法](https://cizixs.com/2017/03/10/kubernetes-intro-scheduler/)
