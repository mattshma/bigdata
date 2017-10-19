# Ceph 简介

Ceph 主要可做 3 方面用：对象存储，块设备和文件系统。Ceph 集群最小配置如下：
- Ceph Monitor   
  维护集群监控信息。
- Ceph OSD             
  存储数据，处理数据的复制，恢复等操作。Ceph 默认有 3 个副本，正常运行的 ODS 守护进程至少和复本数据相同，集群才会达到 `active+clean` 状态。副本数可以修改为其他数字。

当 Ceph 做为文件系统时，还须有元数据服务器（MDS），其主要为 Ceph 文件系统存储元数据（即 Ceph 块设备和 Ceph 对象存储不使用 MDS）。

## Ceph 存储集群   

Ceph 文件系统、Ceph  对象存储和 Ceph 块设备都从 Ceph 存储集群中读写数据。因此这里先介绍 Ceph 存储集群的一些配置和使用。

### Ceph 存储集群配置

