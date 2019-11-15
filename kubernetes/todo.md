
1. 检查内核版本，若低于4.0，需升级，以支持overlay2，升级方法如下：
```
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org \
&& rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm \
&& yum clean all \
&& yum --enablerepo=elrepo-kernel install -y kernel-ml \
&& grub2-set-default 0
```
若版本低于 4.0，docker 会报错：
```
Jun 10 02:19:50 ip-10-1-3-43.nutrainai.local dockerd[30762]: time="2018-06-10T02:19:50.392069604-04:00" level=error msg="[gra
phdriver] prior storage driver overlay2 failed: driver not supported"
Jun 10 02:19:50 ip-10-1-3-43.nutrainai.local dockerd[30762]: Error starting daemon: error initializing graphdriver: driver no
t supported
Jun 10 02:19:50 ip-10-1-3-43.nutrainai.local systemd[1]: docker.service: main process exited, code=exited, status=1/FAILURE
Jun 10 02:19:50 ip-10-1-3-43.nutrainai.local systemd[1]: Failed to start Docker Application Container Engine.
```

2. 注意 k8s 支持的最新的 docker 版本：docker 17.03

3. 
Jun 10 03:42:03 ip-10-1-3-43.nutrainai.local kubelet[2630]: E0610 03:42:03.284959    2630 reflector.go:205] k8s.io/kubernetes
/pkg/kubelet/config/apiserver.go:47: Failed to list *v1.Pod: Get https://10.1.3.43:6443/api/v1/pods?fieldSelector=spec.nodeNa
me%3Dip-10-1-3-43.nutrainai.local&limit=500&resourceVersion=0: dial tcp 10.1.3.43:6443: getsockopt: connection refused
Jun 10 03:42:03 ip-10-1-3-43.nutrainai.local kubelet[2630]: E0610 03:42:03.544890    2630 eviction_manager.go:247] eviction m
anager: failed to get get summary stats: failed to get node info: node "ip-10-1-3-43.nutrainai.local" not found

修改 hosts 文件

4.

```
Jun 10 04:03:10 ip-10-1-3-43.nutrainai.local kubelet[2920]: E0610 04:03:10.386762    2920 pod_workers.go:186] Error syncing p
od edcefd9d0af6d1c6ce79c5687b6a7a80 ("kube-apiserver-ip-10-1-3-43.nutrainai.local_kube-system(edcefd9d0af6d1c6ce79c5687b6a7a8
0)"), skipping: failed to "CreatePodSandbox" for "kube-apiserver-ip-10-1-3-43.nutrainai.local_kube-system(edcefd9d0af6d1c6ce7
9c5687b6a7a80)" with CreatePodSandboxError: "CreatePodSandbox for pod \"kube-apiserver-ip-10-1-3-43.nutrainai.local_kube-syst
em(edcefd9d0af6d1c6ce79c5687b6a7a80)\" failed: rpc error: code = Unknown desc = failed pulling image \"k8s.gcr.io/pause-amd64
:3.1\": Error response from daemon: Get https://k8s.gcr.io/v1/_ping: dial tcp 64.233.188.82:443: i/o timeout"
Jun 10 04:03:10 ip-10-1-3-43.nutrainai.local kubelet[2920]: E0610 04:03:10.388845    2920 remote_runtime.go:92] RunPodSandbox
 from runtime service failed: rpc error: code = Unknown desc = failed pulling image "k8s.gcr.io/pause-amd64:3.1": Error respo
nse from daemon: Get https://k8s.gcr.io/v1/_ping: dial tcp 64.233.188.82:443: i/o timeout
Jun 10 04:03:10 ip-10-1-3-43.nutrainai.local kubelet[2920]: E0610 04:03:10.388880    2920 kuberuntime_sandbox.go:54] CreatePo
dSandbox for pod "etcd-ip-10-1-3-43.nutrainai.local_kube-system(44350a933abc82ce7a9b41f74aabe633)" failed: rpc error: code =
Unknown desc = failed pulling image "k8s.gcr.io/pause-amd64:3.1": Error response from daemon: Get https://k8s.gcr.io/v1/_ping
: dial tcp 64.233.188.82:443: i/o timeout
```
在通过 config 设置了 imageRepository 后，仍需要下载下载：`k8s.gcr.io/pause-amd64:3.1`。查了下[but the kubeadm is using "gcr.io/google_containers/pause-amd64](https://github.com/kubernetes/kubeadm/issues/257#issuecomment-298007840)，即pause-amd64 是通过 kubelet 下载的，而 kubelet 不会使用 kubeadm 的配置，故还需要设置下 kubelet: 

```
cat > /etc/systemd/system/kubelet.service.d/20-pod-infra-image.conf <<EOF
[Service]
Environment="KUBELET_EXTRA_ARGS=--pod-infra-container-image=<your-image>"
EOF
systemctl daemon-reload
systemctl restart kubelet
```


docker pull k8s.gcr.io/pause-amd64:3.1，即image如下：
```
k8s.gcr.io/kube-apiserver-amd64                        v1.10.3             e03746fe22c3        2 weeks ago         225 MB
k8s.gcr.io/kube-scheduler-amd64                        v1.10.3             353b8f1d102e        2 weeks ago         50.4 MB
k8s.gcr.io/kube-controller-manager-amd64               v1.10.3             40c8d10b2d11        2 weeks ago         148 MB
k8s.gcr.io/etcd-amd64                                  3.1.12              52920ad46f5b        3 months ago        193 MB
k8s.gcr.io/pause-amd64                                 3.1                 da86e6ba6ca1        5 months ago        742 kB
```

5. 
Unable to connect to the server: x509: certificate signed by unknown authority (possibly because of "crypto/rsa: verification error" while trying to verify candidate authority certificate "kubernetes")

解决方法：export KUBECONFIG=/etc/kubernetes/kubelet.conf

ansible 中设置 export KUBECONFIG=/etc/..../kubelet.conf >> /etc/bashrc

6. master 执行 `kubectl get pods --all-namespaces`报错：
```
The connection to the server xxxx:6443 was refused - did you specify the right host or port?
```

执行：`export KUBECONFIG=/etc/kubernetes/admin.conf` 即可。


7. dashboard
Error while initializing connection to Kubernetes apiserver. This most likely means that the cluster is misconfigured (e.g., it has invalid apiserver certificates or service accounts configuration) or the --apiserver-host param points to a server that does not exist. Reason: Get http://10.1.3.43:8080/version: dial tcp 10.1.3.43:8080: i/o timeout
