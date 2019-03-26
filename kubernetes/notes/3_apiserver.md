# API Server 分析

和 kubelet 一样，从 [cmd/kube-apiserver/apiserver.go](https://github.com/kubernetes/kubernetes/blob/release-1.13/cmd/kube-apiserver/apiserver.go) 开始看 kube apiserver 的执行过程。如下：

```
command := app.NewAPIServerCommand(server.SetupSignalHandler())
...
if err := command.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
```

调用 [NewAPIServerCommand](https://github.com/kubernetes/kubernetes/blob/release-1.13/cmd/kube-apiserver/app/server.go#L92)，通过 cobra 创建的 `RunE()` 如下：

```
// Run runs the specified APIServer.  This should never exit.
func Run(completeOptions completedServerRunOptions, stopCh <-chan struct{}) error {
	// To help debugging, immediately log version
	klog.Infof("Version: %+v", version.Get())

	server, err := CreateServerChain(completeOptions, stopCh)
	if err != nil {
		return err
	}

	return server.PrepareRun().Run(stopCh)
}
```

查看 [CreateServerChain()](https://github.com/kubernetes/kubernetes/blob/release-1.13/cmd/kube-apiserver/app/server.go#L157)，可以看到其启动了如下几个服务：
- apiExtensionsServer   
  可扩展的 API 服务器。
- kubeAPIServer     
  APIServer 核心服务器。
- aggregatorServer   
  聚合服务器。


### apiExtensionsServer
先看通过 apiextensions-apiserver 中 [New()](https://github.com/kubernetes/apiextensions-apiserver/blob/release-1.13/pkg/apiserver/apiserver.go#L128) 创建 apiExtensionsServer 的过程，创建时会配置扩展 API 相关信息，并启动如下一些关于 CRD 的 Controller：
- crdController    
  crd 控制器。
- namingController      
  用于保留 name，为防止冲突，确保每次只运行一个该实例。
- establishingController   
  控制 CRD 的连接方式与时间。
- finalizingController          
  运行 CRDFinalizer。CRDFinalizer 是一个控制器，通过删除与之相关的所有 CR 来最终确定 CRD。

### kubeAPIServer
接着看 [master.go](https://github.com/kubernetes/kubernetes/blob/release-1.13/pkg/master/master.go#L294) 中创建 kubeAPIServer 的过程:
- 先调用 `c.GenericConfig.New("kube-apiserver", delegationTarget)` 返回一个 `GenericAPIServer` 对象，具体过程如下：

```
func (c completedConfig) New(name string, delegationTarget DelegationTarget) (*GenericAPIServer, error) {
	...
	handlerChainBuilder := func(handler http.Handler) http.Handler {
		return c.BuildHandlerChainFunc(handler, c.Config)
	}
	apiServerHandler := NewAPIServerHandler(name, c.Serializer, handlerChainBuilder, delegationTarget.UnprotectedHandler())

	s := &GenericAPIServer{
		...
		HandlerChainWaitGroup:  c.HandlerChainWaitGroup,
		
		...
		Handler: apiServerHandler,

		listedPathProvider: apiServerHandler,

		postStartHooks:         map[string]postStartHookEntry{},
		preShutdownHooks:       map[string]preShutdownHookEntry{},
		...
		DiscoveryGroupManager: discovery.NewRootAPIsHandler(c.DiscoveryAddresses, c.Serializer),

		enableAPIResponseCompression: c.EnableAPIResponseCompression,
		maxRequestBodyBytes:          c.MaxRequestBodyBytes,
	}
	
	...
	if c.SharedInformerFactory != nil && !s.isPostStartHookRegistered(genericApiServerHookName) {
		err := s.AddPostStartHook(genericApiServerHookName, func(context PostStartHookContext) error {
			c.SharedInformerFactory.Start(context.StopCh)
			return nil
		})
		if err != nil {
			return nil, err
		}
	}

	s.listedPathProvider = routes.ListedPathProviders{s.listedPathProvider, delegationTarget}

	installAPI(s, c.Config)

	// use the UnprotectedHandler from the delegation target to ensure that we don't attempt to double authenticator, authorize,
	// or some other part of the filter chain in delegation cases.
	if delegationTarget.UnprotectedHandler() == nil && c.EnableIndex {
		s.Handler.NonGoRestfulMux.NotFoundHandler(routes.IndexLister{
			StatusCode:   http.StatusNotFound,
			PathProvider: s.listedPathProvider,
		})
	}

	return s, nil
}

```

其中 [NewAPIServerHandler](https://github.com/kubernetes/apiserver/blob/release-1.13/pkg/server/handler.go#L73) 创建一个 APIServerHandler，该 Handler 管理着 API Server 使用的 `http.Handlers`，其定义如下：
```
type APIServerHandler struct {
	// FullHandlerChain is the one that is eventually served with.  It should include the full filter
	// chain and then call the Director.
	FullHandlerChain http.Handler
	// The registered APIs.  InstallAPIs uses this.  Other servers probably shouldn't access this directly.
	GoRestfulContainer *restful.Container
	// NonGoRestfulMux is the final HTTP handler in the chain.
	// It comes after all filters and the API handling
	// This is where other servers can attach handler to various parts of the chain.
	NonGoRestfulMux *mux.PathRecorderMux

	// Director is here so that we can properly handle fall through and proxy cases.
	// This looks a bit bonkers, but here's what's happening.  We need to have /apis handling registered in gorestful in order to have
	// swagger generated for compatibility.  Doing that with `/apis` as a webservice, means that it forcibly 404s (no defaulting allowed)
	// all requests which are not /apis or /apis/.  We need those calls to fall through behind goresful for proper delegation.  Trying to
	// register for a pattern which includes everything behind it doesn't work because gorestful negotiates for verbs and content encoding
	// and all those things go crazy when gorestful really just needs to pass through.  In addition, openapi enforces unique verb constraints
	// which we don't fit into and it still muddies up swagger.  Trying to switch the webservices into a route doesn't work because the
	//  containing webservice faces all the same problems listed above.
	// This leads to the crazy thing done here.  Our mux does what we need, so we'll place it in front of gorestful.  It will introspect to
	// decide if the route is likely to be handled by goresful and route there if needed.  Otherwise, it goes to PostGoRestful mux in
	// order to handle "normal" paths and delegation. Hopefully no API consumers will ever have to deal with this level of detail.  I think
	// we should consider completely removing gorestful.
	// Other servers should only use this opaquely to delegate to an API server.
	Director http.Handler
}
```
- 通过返回的 `GenericAPIServer` 对象创建 `Master` 对象的实例。
- `Master` 实例执行 `m.InstallLegacyAPI(&c, c.GenericConfig.RESTOptionsGetter, legacyRESTStorageProvider)` 安装遗漏的 Rest Storage。
- 创建 restStorageProviders。即设置 API Server 当前提供的 REST API。如下：
```
restStorageProviders := []RESTStorageProvider{
		auditregistrationrest.RESTStorageProvider{},    // REST 地址：auditsinks, for audit.k8s.io
		authenticationrest.RESTStorageProvider{Authenticator: c.GenericConfig.Authentication.Authenticator, APIAudiences: c.GenericConfig.Authentication.APIAudiences},        // REST 地址：tokenreviews
		authorizationrest.RESTStorageProvider{Authorizer: c.GenericConfig.Authorization.Authorizer, RuleResolver: c.GenericConfig.RuleResolver}, 
		autoscalingrest.RESTStorageProvider{},
		batchrest.RESTStorageProvider{},       // 包括 jobs，cronjobs 等 REST
		certificatesrest.RESTStorageProvider{},
		coordinationrest.RESTStorageProvider{},
		extensionsrest.RESTStorageProvider{},  // 包括v1beta1 的 daemonsets，deployments，ingresses，replicasets 等 REST
		networkingrest.RESTStorageProvider{},
		policyrest.RESTStorageProvider{},
		rbacrest.RESTStorageProvider{Authorizer: c.GenericConfig.Authorization.Authorizer},  // RBAC 相关的 REST，如 roles，rolebindings，clusterrolebindings 等。
		schedulingrest.RESTStorageProvider{},
		settingsrest.RESTStorageProvider{},
		storagerest.RESTStorageProvider{},            // 包括 storageclasses，volumeattachments 等 REST
		// keep apps after extensions so legacy clients resolve the extensions versions of shared resource names.
		// See https://github.com/kubernetes/kubernetes/issues/42392
		appsrest.RESTStorageProvider{},  // 包括 v1beta1/v1beta2 的 deployments，statefulsets 等 REST
		admissionregistrationrest.RESTStorageProvider{},
		eventsrest.RESTStorageProvider{TTL: c.ExtraConfig.EventTTL},   // events 相关 REST
	}
```
- `Master` 实例执行 `m.InstallAPIs(c.ExtraConfig.APIResourceConfigSource, c.GenericConfig.RESTOptionsGetter, restStorageProviders...)` 安装 restStorageProviders 的 api 地址。
- 若有设置 Tunneler，则安装。
- 调用 `AddPostStartHookOrDie` 添加名为 `a-registration` 的 Hook。

### aggregatorServer
查看 [createAggregatorServer()](https://github.com/kubernetes/kubernetes/blob/release-1.13/cmd/kube-apiserver/app/aggregator.go#L123)，主要内容如下：
```
func createAggregatorServer(aggregatorConfig *aggregatorapiserver.Config, delegateAPIServer genericapiserver.DelegationTarget, apiExtensionInformers apiextensionsinformers.SharedInformerFactory) (*aggregatorapiserver.APIAggregator, error) {
	aggregatorServer, err := aggregatorConfig.Complete().NewWithDelegate(delegateAPIServer)
	if err != nil {
		return nil, err
	}

	// create controllers for auto-registration
	apiRegistrationClient, err := apiregistrationclient.NewForConfig(aggregatorConfig.GenericConfig.LoopbackClientConfig)
	if err != nil {
		return nil, err
	}
	autoRegistrationController := autoregister.NewAutoRegisterController(aggregatorServer.APIRegistrationInformers.Apiregistration().InternalVersion().APIServices(), apiRegistrationClient)
	apiServices := apiServicesToRegister(delegateAPIServer, autoRegistrationController)
	crdRegistrationController := crdregistration.NewAutoRegistrationController(
		apiExtensionInformers.Apiextensions().InternalVersion().CustomResourceDefinitions(),
		autoRegistrationController)

	aggregatorServer.GenericAPIServer.AddPostStartHook("kube-apiserver-autoregistration", func(context genericapiserver.PostStartHookContext) error {
		go crdRegistrationController.Run(5, context.StopCh)
		go func() {
			// let the CRD controller process the initial set of CRDs before starting the autoregistration controller.
			// this prevents the autoregistration controller's initial sync from deleting APIServices for CRDs that still exist.
			// we only need to do this if CRDs are enabled on this server.  We can't use discovery because we are the source for discovery.
			if aggregatorConfig.GenericConfig.MergedResourceConfig.AnyVersionForGroupEnabled("apiextensions.k8s.io") {
				crdRegistrationController.WaitForInitialSync()
			}
			autoRegistrationController.Run(5, context.StopCh)
		}()
		return nil
	})

	aggregatorServer.GenericAPIServer.AddHealthzChecks(
		makeAPIServiceAvailableHealthzCheck(
			"autoregister-completion",
			apiServices,
			aggregatorServer.APIRegistrationInformers.Apiregistration().InternalVersion().APIServices(),
		),
	)

	return aggregatorServer, nil
}
```

可以看到，其主要负责自动注册及 CRD 注册的实现。

## 参考
- [api-server 源码分析](http://blog.xbblfz.site/2018/08/24/apiserver%E6%BA%90%E7%A0%81%E5%88%86%E6%9E%90/)
- [Kubernetes源码分析——apiserver](https://qiankunli.github.io/2019/01/05/kubernetes_source_apiserver.html)
