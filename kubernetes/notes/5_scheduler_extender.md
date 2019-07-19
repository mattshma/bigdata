# Scheduler Extender

有如下三种方式来自定义调度规则：    
- 将这些规则添加到 `Predicate` 和 `Priority` 后重新编译，见 [scheduler](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-scheduling/scheduler.md)。
- 使用自定义的调度器来代替 Kubernetes 默认的调度器，参考[Specify schedulers for pods](https://kubernetes.io/docs/tasks/administer-cluster/configure-multiple-schedulers/#specify-schedulers-for-pods)，通过指定 pod 的 `spec.schedulerName`，即可使用自定义的调度器。
- 实现一个 "scheduler extender"，在 Kubernetes 调度器做调度决定时，会由该 extender 做出最后决定。


## Extender 结构
这里主要讨论第三种方法。对不由默认 Kubernetes 调度器直接管理的资源进行调度决策时，需要使用此方法，Scheduler extender 有助于根据这些资源做出调度决策。

当调度 pod 时，extender 允许外部进程 fitler 和 prioritize 节点。两个独立的 http/https 请求会发送给 extender，一个用于 filter，一个用于 prioritize。另外，extender 能实现 bind 操作来将 pod 绑定给 apiserver。为了使用 extender，需先创建一个调度策略的配置文件，该配置文件指定如何到达 extender，是否使用 http/https 和 timeout 等。

```
// Holds the parameters used to communicate with the extender. If a verb is unspecified/empty,
// it is assumed that the extender chose not to provide that extension.
type ExtenderConfig struct {
	// URLPrefix at which the extender is available
	URLPrefix string `json:"urlPrefix"`
	// Verb for the filter call, empty if not supported. This verb is appended to the URLPrefix when issuing the filter call to extender.
	FilterVerb string `json:"filterVerb,omitempty"`
	// Verb for the prioritize call, empty if not supported. This verb is appended to the URLPrefix when issuing the prioritize call to extender.
	PrioritizeVerb string `json:"prioritizeVerb,omitempty"`
	// Verb for the bind call, empty if not supported. This verb is appended to the URLPrefix when issuing the bind call to extender.
	// If this method is implemented by the extender, it is the extender's responsibility to bind the pod to apiserver.
	BindVerb string `json:"bindVerb,omitempty"`
	// The numeric multiplier for the node scores that the prioritize call generates.
	// The weight should be a positive integer
	Weight int `json:"weight,omitempty"`
	// EnableHttps specifies whether https should be used to communicate with the extender
	EnableHttps bool `json:"enableHttps,omitempty"`
	// TLSConfig specifies the transport layer security config
	TLSConfig *client.TLSClientConfig `json:"tlsConfig,omitempty"`
	// HTTPTimeout specifies the timeout duration for a call to the extender. Filter timeout fails the scheduling of the pod. Prioritize
	// timeout is ignored, k8s/other extenders priorities are used to select the node.
	HTTPTimeout time.Duration `json:"httpTimeout,omitempty"`
}
```

如下是一份包括 extender 的调度策略配置文件：
```
{
  "predicates": [
    {
      "name": "HostName"
    },
    {
      "name": "MatchNodeSelector"
    },
    {
      "name": "PodFitsResources"
    }
  ],
  "priorities": [
    {
      "name": "LeastRequestedPriority",
      "weight": 1
    }
  ],
  "extenders": [
    {
      "urlPrefix": "http://127.0.0.1:12345/api/scheduler",
      "filterVerb": "filter",
      "enableHttps": false
    }
  ]
}
```

传递给 extender FilterVerb endpoint 的参数是一系列通过 k8s predicate 过滤的 node 集和 pod，传递给 extender PrioritizeVerb endpoint 的参数是一系列通过 k8s predicates 和 extender predicates 过滤的 node 集和 pod。
```
type ExtenderArgs struct {
	// Pod being scheduled
	Pod   api.Pod      `json:"pod"`
	// List of candidate nodes where the pod can be scheduled
	Nodes api.NodeList `json:"nodes"`
}
```

- filter 请求返回一个 node 集，node 集可能会基于 predicates 进行裁剪。
- prioritize 请求返回每个 node 的优先级。
- bind 请求用于将 pod 绑定 node 的操作委托给 extender。
  ```
  // ExtenderBindingArgs represents the arguments to an extender for binding a pod to a node.
  type ExtenderBindingArgs struct {
  	// PodName is the name of the pod being bound
  	PodName string
  	// PodNamespace is the namespace of the pod being bound
  	PodNamespace string
  	// PodUID is the UID of the pod being bound
  	PodUID types.UID
  	// Node selected by the scheduler
  	Node string
  }
  ```

## Scheduler Extender 工作流程

默认情况下，Scheduler 的工作流程如下：
- 根据给定的参数启动默认的调度器。
- 监控 apiserver，将 `spec.nodeName` 为空的 pod 放到内部调度队列中。
- 从调度队列中取出 pod 并开始一个标准的调度循环。
- 从 pod 的 spec 属性中获取“硬性要求”（如 cpu/memory 的请求量，nodeSelector/nodeAffinity 等），接着 predicates 阶段根据这些要求选出候选的机器。
- 从 pod 的 spec 属性中获取“软性要求”并结合一些默认的策略（如 pod 是在各节点上分散还是集中），给候选的各机器打分，并最终选出分数最高的节点。
- 发出 bind 请求通知 apiserver，并设置 `spec.nodeName` 来指示 pod 该调度到该 node 上。

在上述调度周期中，有一些和 Scheduler Extender 相关的扩展。

### 启动参数
在 Scheduler 启动时，通过 `--config` 可指定使用的调度配置文件，参考 [KubeSchedulerConfiguration](https://godoc.org/k8s.io/kubernetes/pkg/scheduler/apis/config#KubeSchedulerConfiguration)，配置文件应格式如下：
```
 apiVersion: kubescheduler.config.k8s.io/v1alpha1
 kind: KubeSchedulerConfiguration
 clientConnection:
   kubeconfig: "/var/run/kubernetes/scheduler.kubeconfig"
 algorithmSource:
   policy:
     file:
       path: "/root/config/scheduler-extender-policy.json"
```

其中的 `algorithmSource.policy` 即为配置文件的地址，可为本地文件或 ConfigMap，这里以本地文件为例，该文件格式为 [Policy](https://godoc.org/k8s.io/kubernetes/pkg/scheduler/api/v1#Policy) 且须为 [JSON 格式或 YAML格式](https://github.com/kubernetes/kubernetes/pull/75857)，如下：

```
{
    "kind" : "Policy",
    "apiVersion" : "v1",
    "extenders" : [{
        "urlPrefix": "http://localhost:8888/",
        "filterVerb": "filter",
        "prioritizeVerb": "prioritize",
        "weight": 1,
        "enableHttps": false
    }]
}
```

该文件表示 http extender 服务运行在 localhost:8888 并注册在默认调度器中，在 Predicate 和 Priority 阶段结束后，结果将会传递给 extender 服务的 `<urlPrefix>/<filterVerb>` 和 `<urlPrefix>/<prioritizeVerb>` 路径，在 extender 中，可根据需求进一步选择节点。

### extender 处理请求
接下来看下 extender 服务相关的内容。

extender 服务能以任何语言编写，这里以 Golang 为例：
```
func main() {
    router := httprouter.New()
    router.GET("/", Index)
    router.POST("/filter", Filter)
    router.POST("/prioritize", Prioritize)

    log.Fatal(http.ListenAndServe(":8888", router))
}
```

上述代码对应配置文件中的路径。接着编写 `Filter` 和 `Prioritize` 方法。`Filter` 方法接收 `schedulerapi.ExtenderArgs` 类型的参数并返回 `*schedulerapi.ExtenderFilterResult` 类型的结果。在该方法中，可进一步的过滤传入的节点，如下：

```
// filter filters nodes according to predicates defined in this extender
// it's webhooked to pkg/scheduler/core/generic_scheduler.go#findNodesThatFit()
func filter(args schedulerapi.ExtenderArgs) *schedulerapi.ExtenderFilterResult {
    var filteredNodes []v1.Node
    failedNodes := make(schedulerapi.FailedNodesMap)
    pod := args.Pod

    for _, node := range args.Nodes.Items {
        fits, failReasons, _ := podFitsOnNode(pod, node)
        if fits {
            filteredNodes = append(filteredNodes, node)
        } else {
            failedNodes[node.Name] = strings.Join(failReasons, ",")
        }
    }

    result := schedulerapi.ExtenderFilterResult{
        Nodes: &v1.NodeList{
            Items: filteredNodes,
        },
        FailedNodes: failedNodes,
        Error:       "",
    }

    return &result
}
```

在上述方法中，通过遍历每个节点传递给 `podFitsOnNode()` 来判断节点是否合适，在 `podFitsOnNode()` 实现业务相关的代码即可。`Prioritize` 方法类似：

```
// it's webhooked to pkg/scheduler/core/generic_scheduler.go#PrioritizeNodes()
// you can't see existing scores calculated so far by default scheduler
// instead, scores output by this function will be added back to default scheduler
func prioritize(args schedulerapi.ExtenderArgs) *schedulerapi.HostPriorityList {
    pod := args.Pod
    nodes := args.Nodes.Items

    hostPriorityList := make(schedulerapi.HostPriorityList, len(nodes))
    for i, node := range nodes {
        score := rand.Intn(schedulerapi.MaxPriority + 1)
        log.Printf(luckyPrioMsg, pod.Name, pod.Namespace, score)
        hostPriorityList[i] = schedulerapi.HostPriority{
            Host:  node.Name,
            Score: score,
        }
    }

    return &hostPriorityList
}
```

一般而言，以上两个方法是默认调度器最重要的扩展，对于个别场景，还可以实现 extender 的 `preempt` 和 `bind` 来进一步扩展调度器。

### 缺点

虽然 Scheduler Extender 提高了调度器的灵活性，但也有如下缺点：      
- 通信代价：数据在默认调度器和调度器扩展中传输，会带来数据编码解码的性能损失。
- 有限的扩展点：如上所述，extender 只能在几个特定阶段（如 Filter 和 Proritize）结束后才能调用，而不能在这些阶段中执行前或执行中调用。
- 减少而非加法：默认调度器传过来候选节点后，若需要添加节点，则新加入的节点可能无法满足默认器中的一些要求（如 cpu/memory 等），因此 extender 一般更合适做减法而非加法。
- 共享缓存：默认调度器的 cache 无法与 extender 共享。

基于以上几点，Kuberentes scheduler 组提出了第四种方法：[Scheduler Framework](https://github.com/kubernetes/enhancements/blob/master/keps/sig-scheduling/20180409-scheduling-framework.md)，其将解决上述的几个问题，并将成为官方推荐的调度扩展。


## 参考
- [Scheduler extender](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/scheduling/scheduler_extender.md)
- [Extending your Kubernetes Cluster](https://kubernetes.io/docs/concepts/extend-kubernetes/extend-cluster/)
- [Create a custom Kubernetes scheduler](https://developer.ibm.com/articles/creating-a-custom-kube-scheduler/)
- [Scheduling Framework](https://kubernetes.io/docs/concepts/configuration/scheduling-framework/)
