HBase Install
===

本文按照官方文档中的步骤安装使用HBase，简要记录下遇到的问题。这里依旧以之前安装 Hadoop 的三台机器为例。三台机器情况如下：

```
10.10.9.52 hadoop-master
10.10.9.54 hadoop-slave1
10.10.9.60 hadoop-slave2
```

下载 HBase 及一些注意事项如 ssh 登录，ntp 同步时间等此不赘述。

伪分布模式
---

若之前 `/etc/hosts` 中没有设置 `localhost`，需要增加对 `localhost` 的解析。

```
10.10.9.52      hadoop-master
10.10.9.54      hadoop-slave1
10.10.9.60      hadoop-slave2

127.0.0.1   localhost

```

### 修改 `conf/hbase-env.sh`

设置 `JAVA_HOME` 目录，增加如下行：

```
export JAVA_HOME=/root/software/jdk1.7.0_67
```

### 修改 `conf/hbase-site.xml`

因为之前安装 Hadoop 时，配置的端口为9000，所以这里仍使用了9000。内容修改为如下：

```
<configuration>
  <property>
    <name>hbase.rootdir</name>
    <value>hdfs://10.10.9.52:9000/hbase</value>
  </property>
  <property>
    <name>hbase.zookeeper.property.dataDir</name>
    <value>/root/software/hbase-0.98.1-cdh5.1.2/data/zookeeper</value>
  </property>
  <property>
    <name>hbase.cluster.distributed</name>
    <value>true</value>
  </property>
</configuration>
```
这里不需要手动创建 `/hbase` 目录。HBase 会自动创建这个目录。


### 启动 hbase 服务

```
# bin/start-hbase.sh
localhost: starting zookeeper, logging to /root/software/hbase-0.98.1-cdh5.1.2/bin/../logs/hbase-root-zookeeper-hadoop-master.out
starting master, logging to /root/software/hbase-0.98.1-cdh5.1.2/bin/../logs/hbase-root-master-hadoop-master.out
localhost: starting regionserver, logging to /root/software/hbase-0.98.1-cdh5.1.2/bin/../logs/hbase-root-regionserver-hadoop-master.out
# jps
908 SecondaryNameNode
13595 HQuorumPeer
13901 HRegionServer
13658 HMaster
13967 Jps
603 NameNode
1057 ResourceManager
```

查看 `/hbase` 目录

```
# hdfs dfs -ls /hbase
Found 6 items
drwxr-xr-x   - root supergroup          0 2014-10-08 15:51 /hbase/.tmp
drwxr-xr-x   - root supergroup          0 2014-10-08 15:51 /hbase/WALs
drwxr-xr-x   - root supergroup          0 2014-10-08 15:51 /hbase/data
-rw-r--r--   2 root supergroup         42 2014-10-08 15:51 /hbase/hbase.id
-rw-r--r--   2 root supergroup          7 2014-10-08 15:51 /hbase/hbase.version
drwxr-xr-x   - root supergroup          0 2014-10-08 15:51 /hbase/oldWALs
```

接下来可以启动备份的 HMaster 或者多余的 RegionServers 。

在终端输入 `bin/hbase shell` 可以在 shell 中操作 hbase 。

全分布模式
---

### 修改 `conf/regionservers`

删除 `localhost` 这行后，添加如下行：

```
hadoop-master
hadoop-slave1
hadoop-slave2
```

### 修改 `conf/hbase-site.xml`

如下：
```
<configuration>
  <property>
    <name>hbase.rootdir</name>
    <value>hdfs://10.10.9.52:9000/hbase</value>
  </property>
  <property>
    <name>hbase.zookeeper.quorum</name>
    <value>hadoop-master, hadoop-slave1, hadoop-slave2</value>
  </property>
  <property>
    <name>hbase.zookeeper.property.dataDir</name>
    <value>/root/software/hbase-0.98.1-cdh5.1.2/data/zookeeper</value>
  </property>
  <property>
    <name>hbase.cluster.distributed</name>
    <value>true</value>
  </property>
</configuration>
```

### slave 机器安装 HBase

slave 上下载 HBase 并解压，再将 master 上的 `conf` 目录同步过去。 

### 启动 HBase

master 端启动 `bin/start-hbase.sh` 后，输入 `jps`，如下：

```
# jps
18622 HMaster
18889 HRegionServer
908 SecondaryNameNode
603 NameNode
19259 Jps
1057 ResourceManager
18557 HQuorumPeer
```

而两个 slave 终端输入 `jps` 可以看到启动的进程如下：

```
# jps
32501 DataNode
32197 HQuorumPeer
32477 Jps
32409 HRegionServer
```

在 web 中输入 masterip:60010 可以查看 Master，输入 masterip:60030 可以查看 RegionServer。

