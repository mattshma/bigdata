# Service 介绍

Service 是一组 Pods 在逻辑上的抽象，并提供了对 Pods 的访问入口。Service 通常通过 Label Selector 来找到 Pod，此时会自动创建与 Service 同名的 Endpoints 并将数据 POST 给该 Endpoints。若不指定 Label Selector，则需要手动关联对应的 Endpoints。

对于 Kubernetes 原生应用，当 Service 中的 Pods 发生变化时，Kuberentes 会更新 Servcie 对应的 Endpoints 来感知变化。对于非原生应用，Kubernetes 为 Service 提供一个能直接访问后端 Pods 的虚拟 IP 网桥。

## 定义 Service
如下是一个典型的 Service 创建文件：

```
kind: Service
apiVersion: v1
metadata:
  name: my-service
spec:
  selector:
    app: MyApp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 9376
    nodePort: 300061
```

- port 是 Service 暴露的端口，其是提供给集群内部用户访问 Service 的入口。
- nodePort 是启动在容器宿主机上的端口，其是 Kuberentes 提供给集群外部用户访问 Service 的一种入口。其他访问 Service 的方式会在下文叙述。
- targetPort 是 Service 后的 pod 上的端口，从 port 和 nodePort 上进来的数据通过 kube-proxy 从 pod 的 targetPort 上进入容器。

## VIP 和 Service 代理
Kubernetes 集群中的每个节点都会运行 `kube-proxy` 服务。`kube-proxy` 为 Service 提供 VIP 形式的实现。不同版本的 Kubernetes 中 kube-proxy 实现不同。在 Kubernetes v1.0 版本中，service 是 4 层概念，proxy 全在 userspace 中。而在 Kubernetes v1.1 中，引入了 Ingress 来代表 7 层服务，且增加了 iptables proxy。在 Kuberentes v1.8.0-beta.0 中，又添加了 ipvs proxy 代理。

### Proxy-mode: userspace
在这种模式下，kube-proxy 监听 Kubernetes Maser 对 `Service` 和 `Endpoints` 的添加和删除操作。对于每个 Service 对象，proxy 会在本地节点上随机选择一个 port，该代理端口上（serviceIP:port）的所有连接都会被 proxy 捕获，接着安装 iptables 规则用于转发给 Service 后端的 Pods。默认使用 round-robin 算法来选择 Pod。

![userspace](../img/services-userspace-overview.svg)



