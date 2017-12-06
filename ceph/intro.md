# Ceph 简介[非正式版]

*本文主要来自于官网*

Ceph 主要可做 3 方面用：对象存储，块设备和文件系统。Ceph 集群最小配置如下：
- Ceph Monitor   
  维护集群监控信息。
- Ceph OSD             
  存储数据，处理数据的复制，恢复等操作。Ceph 默认有 3 个副本，正常运行的 ODS 守护进程至少和复本数据相同，集群才会达到 `active+clean` 状态。副本数可以修改为其他数字。

当 Ceph 做为文件系统时，还须有元数据服务器（MDS），其主要为 Ceph 文件系统存储元数据（即 Ceph 块设备和 Ceph 对象存储不使用 MDS）。

## Ceph 存储集群   

Ceph 文件系统、Ceph  对象存储和 Ceph 块设备都从 Ceph 存储集群中读写数据。因此这里先介绍 Ceph 存储集群的一些配置和使用。

### Ceph 存储集群配置

#### 文件系统   
OSD 守护进程依赖底层文件系统的扩展属性（XATTR）存储各种内部对象状态和元数据，所以底层文件系统必须能为 XATTR 提供足够容量；xfs 限制 XATTR 容量为 64 KB，多数情况不会瓶颈，而 ext4 限制 XTTAR 容量为 4KB，因此若文件系统为 ext4，必须将如下行添加到 `ceph.conf` 中的 `[osd]` 段下：
```
filestore xattr use omap = true
```

#### 配置文件
##### Ceph 文件位置        
启动 Ceph 集群时，各守护进行都从默认的 ceph.conf 文件中读取各自配置，ceph.conf 默认读取顺序如下：

- 环境变量中指示的 $CEPH_CONF
- 启动命令中通过 `-c path/path`指定文件位置
- /etc/ceph/ceph.conf
- ~/.ceph/config
- ./ceph.conf（即当前工作路径）

##### Ceph 配置段落   
Ceph 的配置段落如下：
   段落 | 描述  | 实例
---------|---------|------------
 [global] | 影响 Ceph 集群里的所有守护进程 | auth cluster supported = cephx
 [osd] | 影响集群里的所有 ceph-osd 进程，并且会覆盖 [global] 下的同一选项 | osd journal size = 1000
 [mon] | 影响集群里的所有 ceph-mon 进程，并且会覆盖 [global] 下的同一选项 | mon addr = 10.0.0.101:6789
 [mds] | 影响集群里的所有 ceph-mds 进程，并且会覆盖 [global] 下的同一选项 | host = myserver01
 [client] | 影响所有客户端（如挂载的 Ceph 文件系统、挂载的块设备等等）| log file = /var/log/ceph/radosgw.log

配置段落可具体到某个特定例程。例程由类型和及其例程 ID 确定，OSD 的例程 ID 只能是数字，但监视器和元数据服务器的 ID 可包含字母和数字，如`[osd.1]`、`[mon.a]`等。

##### Ceph 元变量    

Ceph 会把配置的元变量展开为具体值；类似为 shell 扩展。

  元变量  | 描述    | 实例
---------|-----------------|------------
 $cluster | 展开为存储集群名字，在同一套硬件上运行多个集群时有用。默认值为 `ceph`| /etc/ceph/$cluster.keyring
 $type | 可展开为 mds、osd、mon 中的一个，信赖于当前守护进程的类型 | /var/lib/ceph/$type
 $id | 展开为守护进程标识符；osd.0 应为 0，mds.a 是 a | /var/lib/ceph/$type/$cluster-$id
 $host | 展开为主机名| 
 $name | 展开为 $type.$id  | /var/run/ceph/$cluster-$name.asok 

#### 监视器     

监视器图、OSD 图、归置组图和元数据服务器图组成集群运行图。监视器维护着集群运行图的主副本，即当客户端连到一个监视器并获取当前运行图，再根据 CRUSH 算法就能确定所有监视器、OSD 和元数据服务器的位置。监视器把监视器服务的所有更改写入 Paxos 例程，Paxos 以 key/value 存储所有变更变更以实现高度一性性，Ceph 以 LevelDB 做为 key/value 存储。

Ceph 生产集群至少部署 3 个监视器来确保高可靠性，它允许一个监视器例程崩溃。奇数个监视器确保 PAXOS 算法能确定一批监视器里哪个版本的集群运行图是最新的。默认情况下，Ceph 会在 `/var/lib/ceph/mon/$cluster-$id` 这个目录存储监视器数据。

Ceph 客户端和其他守护进程使用配置文件发现监视器，而监视器通过参考监视器图（monmap）的本地副本而非配置文件来互相发现，这是因为 monmap 的变更都是通过 Paxos 的分布式一致性算法传递的，其可确保法定人数里的每个监视器 monmap 版本相同，而配置文件可能因为不小心使用较老的配置文件以致不能确定当前系统状态。

Ceph 监视器一般需要如下几个设置：
- Filesystem ID    
  fsid 是 Ceph 存储集群的唯一标识符，通常部署工具（如 `ceph-deploy`）会自己生成并存在监视器图中，所以该配置不一定在配置文件中。如果自己指定的话，它应该出现在配置文件的 `[global]` 段下。fsid 使得在一套硬件上运行多个集群成为可能。 
- Monitor ID    
  监视器标识符是分配给集群内各监视器的唯一 ID，它是一个字母数字组合，为方便起见，标识符通常以字母顺序结尾（如 a、b 等等）。
- Keys     
  监视器必须有密钥。像 ceph-deploy 这样的部署工具通常会自动生成，也可以手动完成。 

在 Ceph 配置文件中，如果部署工具会自动给你生成 fsid 和 mon. 密钥，那么 Ceph 监视器的最简配置必须包括一主机名及其监视器地址，这些配置可置于 [mon] 下或某个监视器下，如下：
```
[mon]
        mon host = hostname1,hostname2,hostname3
        mon addr = 10.0.0.10:6789,10.0.0.11:6789,10.0.0.12:6789
```

关于监视器存储同步，参考官网说明：
> 当你用多个监视器支撑一个生产集群时，各监视器都要检查邻居是否有集群运行图的最新版本（如，邻居监视器的图有一或多个 epoch 版本高于当前监视器的最高版 epoch ），过一段时间，集群里的某个监视器可能落后于其它监视器太多而不得不离开法定人数，然后同步到集群当前状态，并重回法定人数。为了同步，监视器可能承担三种中的一种角色：
> - Leader: Leader 是实现最新 Paxos 版本的第一个监视器。
> - Provider: Provider 有最新集群运行图的监视器，但不是第一个实现最新版。
> - Requester: Requester 落后于 leader ，重回法定人数前，必须同步以获取关于集群的最新信息。
> 有了这些角色区分， leader就 可以给 provider 委派同步任务，这会避免同步请求压垮 leader 、影响性能。在下面的图示中， requester 已经知道它落后于其它监视器，然后向 leader 请求同步， leader 让它去和 provider 同步。

#### OSD
默认情况下，Ceph 把 OSD 数据储存在 `/var/lib/ceph/osd/$cluster-$id` 这个目录中，一般把磁盘挂载在这些目录，不推荐修改默认值。OSD 日志默认存储在 `/var/lib/ceph/osd/$cluster-$id/journal` 中。

当集群新增或移除 OSD 时，按照 CRUSH 算法应该重新均衡集群，它会把一些归置组移出或移入多个 OSD 以回到均衡状态。归置组和对象的迁移会导致集群运营性能显著降低，为维持运营性能， Ceph 用 backfilling 来执行此迁移，它可以使得 Ceph 的回填操作优先级低于用户读写请求。

Ceph 可在运行时动态修改配置：`ceph tell {daemon-type}.{id or *} injectargs --{name} {value} [--{name} {value}]`，其中 `daemon-type` 为 `osd`、`mon`、`mds` 中的一个，也可用 `*` 代表所有例程。在 ceph.conf 文件里配置时用空格分隔关键词，在命令行中使用下划线或连字符（ _ 或 - ）分隔，如 `debug osd` 变成 `debug-osd`。

而如果想查看正在运行集群中的配置，可使用命令：`ceph daemon {daemon-type}.{id} config show | less`。

Ceph 存储集群利用率接近最大容量时（即 mon osd full ratio ），作为防止数据丢失的安全措施，它会阻止你读写 OSD 。因此，让生产集群用满可不是好事，因为牺牲了高可用性。 full ratio 默认值是 .95 或容量的 95%。

#### 监视器与 OSD 交互的配置

- 各 OSD 每 6 秒会与其他 OSD 进行心跳检查，用 [osd] 下的 osd heartbeat interval 可更改此间隔、或运行时更改。
- 如果一个 OSD 20 秒都没有心跳，集群就认为它 down 了，用 [osd] 下的 `osd heartbeat grace` 可更改宽限期、或者运行时更改。
- 一个 OSD 必须向监视器报告三次另一个 OSD down 的消息，监视器才会认为那个被报告的 OSD down 了，可通常修改配置文件里 [mon] 段下的 `mon osd min down reports` 来修改次数。
- 默认情况下只要有一个 OSD 报告另一个 OSD 挂的消息即可，可通过修改配置文件里 [mon] 段下的 `mon osd min down reporters` 来更改必需 OSD 数。
- 如果一 OSD 在 `mon osd report timeout` 时间内没向监视器报告过，监视器就认为它 down 了。

### 部署
#### 管理 OSD
- 列举磁盘：`ceph-deploy disk list {node-name [node-name]...}`。
- 擦除磁盘：`ceph-deploy disk zap {osd-server-name}:{disk-name}`。
- 准备 OSD：`ceph-deploy osd prepare {node-name}:{data-disk}[:{journal-disk}]`。
- 激活 OSD：`ceph-deploy osd activate {node-name}:{data-disk-partition}[:{journal-disk-partition}]`。
- 创建 OSD：`ceph-deploy osd create {node-name}:{disk}[:{path/to/journal}]`。该命令相当于 `prepare` + `activate`。

#### 数据归置

Ceph 数据归置主要有如下几个概念：
- Pool（存储池）      
Ceph 在存储池内存储数据，它是对象存储的逻辑组；存储池管理着归置组数量、副本数量、和存储池规则集。
- Placement Group（归置组）       
Ceph 把对象映射到归置组（ PG ），归置组是一逻辑对象池的片段，这些对象组团后再存入到 OSD。 
- CRUSH Map （CRUSH 图）         
CRUSH 是重要组件，它使 Ceph 能伸缩自如而没有性能瓶颈、没有扩展限制、没有单点故障，它为 CRUSH 算法提供集群的物理拓扑，以此确定一个对象的数据及它的副本应该在哪里、怎样跨故障域存储，以提升数据安全。

##### Pool
存储池提供如下功能：
- 自动恢复：在不丢失数据的前提下，当数据副本数少于指定副本数时，会自动恢复到指定副本数。
- 设置归置组数量。
- 控制 CRUSH 规则。
- 提供快照功能。
- 设置存储池所有者。

以下是一些常用的命令：
- `ceph osd lspools`：列出集群的存储池。
- `ceph osd pool set-quota {pool-name} [max_objects {obj-count}] [max_bytes {bytes}]`：设置存储池配额。
- `rados df`：查看存储池统计信息。
- `ceph osd pool set {pool-name} {key} {value}`：调整存储池选项值。



##### Placement Group
储池内的归置组（ PG ）把对象汇聚在一起，因为跟踪每一个对象的位置及其元数据需要大量计算——即一个拥有数百万对象的系统，不可能在对象这一级追踪位置。Ceph 客户端会计算某一对象应该位于哪个归置组里，它是这样实现的，先给对象 ID 做哈希操作，然后再根据指定存储池里的 PG 数量、存储池 ID 做一个运算。

##### CRUSH 
Ceph 客户端连接 OSD 时，CRUSH 算法通过计算数据存储位置来确定如何存储和检索，而非通过某个中央服务器，这使 Ceph 避免了单点故障、性能瓶颈和伸缩的物理限制。

由于对所安装底层物理组织的表达， CRUSH 能模型化、并因此定位到潜在的相关失败设备源头，典型的源头有物理距离、共享电源、和共享网络，把这些信息编码到集群运行图里， CRUSH 归置策略可把对象副本分离到不同的失败域，却仍能保持期望的分布。例如，要定位同时失败的可能性，可能希望保证数据复制到的设备位于不同机架、不同托盘、不同电源、不同控制器、甚至不同物理位置。

用 CRUSH 图层次结构所表示的 OSD 位置被称为“ crush 位置”，它用键/值对列表来表示，如下：
```
root=default row=a rack=a2 chassis=a2a host=a2a1
```
键名（ = 左边）必须是 CRUSH 内的合法 type ，默认情况下，它包含 root、datacenter、room、row、pod、pdu、rack、chassis 和 host，但这些类型可修改 CRUSH 图任意定义。

CRUSH 图主要有 4 个主要段落：
- 设备    
  由任意对象存储设备组成，即对应一个 ceph-osd 进程的存储器。 Ceph 配置文件里的每个 OSD 都应该有一个设备。
- 桶类型    
  定义了 CRUSH 分级结构里要用的桶类型（ types ），桶由逐级汇聚的存储位置（如行、机柜、机箱、主机等等）及其权重组成。
- 桶例程   
  定义了桶类型后，还必须声明主机的桶类型、以及规划的其它故障域。
- 规则     
  由选择桶的方法组成。
