# 通过 kubeadm 安装 k8s

## 准备工作
- 关闭 swap    
执行 `swapoff -a` 并注释 `/etc/fstab` 中关于 swap  的行。

在 https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64/repodata/primary.xml 中，可以看到各版本 kubernetes 组件的下载地址。在一台能下载 rpm 包的机器上，下载 kubeadm, kubelet 等 rpm 包。

