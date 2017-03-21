Hadoop 安装手册
===

前言
---

在安装前，可以看下系统要求，见 [JAVA JDK](http://www.cloudera.com/content/cloudera-content/cloudera-docs/CDH5/latest/CDH5-Requirements-and-Supported-Versions/cdhrsv_jdk.html)

Hadoop有三种安装模式：单机模式（Standalone Mode）, 伪分布模式（Pseudo-Distributed Mode）, 全分布模式（Fully Distributed Mode）。

单机模式为Hadoop默认模式。当解压hadoop的tarbal后，3个XML文件均为空文件，当这3个文件均为空文件时，Hadoop会完全运行在本地。单机模式下Hadoop不会使用HDFS，也不会加载Hadoop的守护进程。伪分布模式即所有结点都运行在同一台机器上。而全分布模式即结点在Hadoop集群中。

安装Hadoop
----

### 准备条件
- JDK1.7+ (这里使用JDK1.8，因为 Hadoop3/Spark2 只支持 JDK1.8+)
- ssh 免密登录
- Centos 6.4+ （其他 Linux 操作系统也行）

### 安装 jdk-8u121
下载 [jdk-8u121-linux-x64.tar.gz](http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html)，解压后放在 /usr/java 目录下，将 latest 软链 jdk1.8.0_121。执行 `echo $JAVA_HOME` 查看结果。

### 安装 Hadoop2.7.3
下载 [hadoop-2.7.3.tar.gz](http://apache.website-solution.net/hadoop/common/hadoop-2.7.3/hadoop-2.7.3.tar.gz)，解压放在 /opt 目录，执行下列命令：
```
# cd /opt
# ln -s hadoop-2.7.3 hadoop
# cd hadoop
# bin/hadoop version
Hadoop 2.7.3
```

编辑 /opt/hadoop/etc/hadoop/hadoop-env.sh 文件，设置 `export JAVA_HOME=/usr/java/latest`。编辑 /etc/bashrc，添加 `export HADOOP_PREFIX=/opt/hadoop`。

## 配置

再分别说下3种模式的配置情况

### 单机模式


单机模式不需要进行任何配置。此时直接运行Hadoop，如下

```
# bin/hadoop jar share/hadoop/mapreduce/hadoop-mapreduce-examples-2.7.3.jar wordcount README.txt wordcount_output
```

在 wordcount_output 文件夹中即可以看到结果。

### 伪分布模式

#### 修改 `$HADOOP_PREFIX/etc/hadoop/core-site.xml`

增加如下配置  

```
<configuration>
    <!-- 设置nameserive -->
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://localhost:9000</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>file:///data/hadoop/tmp</value>
    </property>
   <!-- 添加lzo等-->
    <property>
        <name>io.compression.codecs</name>
        <value>org.apache.hadoop.io.compress.DefaultCodec,com.hadoop.compression.lzo.LzopCodec,org.apache.hadoop.io.compress.GzipCodec,org.apache.hadoop.io.compress.BZip2Codec,org.apache.hadoop.io.compress.DeflateCodec,org.apache.hadoop.io.compress.SnappyCodec,org.apache.hadoop.io.compress.Lz4Codec</value>
    </property>
    <!--  设置http user为yarn，用于查看日志 -->
    <property>
         <name>hadoop.http.staticuser.user</name>
         <value>yarn</value>
    </property>
    <!-- 开启回收站，设置为7天 -->
    <property>
         <name>fs.trash.interval</name>
         <value>10080</value>
    </property>
</configuration>
```

`fs.defaultFS` 用于设置hadoop的默认文件系统，文件系统由URI指定。HDFS的守护进程通过该属性来确定HDFS的namenode和端口（默认端口是8020）。

这里特别注意 `hadoop.tmp.dir` 目录，其用于存放临时数据，默认为 `/tmp/hadoop-${user.name}`，在 Linux 系统中，若机器宕机时，/tmp 目录下的数据会清空，此时可能引起相关服务丢数据并导致异常。

#### 修改 `$HADOOP_PREFIX/etc/hadoop/hdfs-site.xml`

增加如下配置  

```
<configuration>
    <property>
      <name>dfs.nameservices</name>
      <value>mytest</value>
    </property>
    <property>
      <name>dfs.namenode.name.dir</name>
      <value>file:///data/hadoop/dfs/nn</value>
    </property>
    <property>
      <name>dfs.datanode.data.dir</name>
      <value>file:///data/hadoop/dfs/dn</value>
    </property>
    <property>
      <name>dfs.journalnode.edits.dir</name>
      <value>file:///data/hadoop/dfs/jn</value>
    </property>
    <property>
      <name>dfs.namenode.checkpoint.dir</name>
      <value>file:///data/hadoop/dfs/snn</value>
    </property>
    <property>
      <name>dfs.replication</name>
      <value>1</value>
    </property>
    <property>
      <name>dfs.datanode.balance.bandwidthPerSec</name>
      <value>104857600</value>
    </property>
    <property>
      <name>dfs.namenode.handler.count</name>
      <value>256</value>
    </property>
    <property>
      <name>dfs.datanode.handler.count</name>
      <value>256</value>
    </property>
    <property>
      <name>dfs.datanode.max.transfer.threads</name>
      <value>10240</value>
    </property>
    <!-- shortcirruit -->
    <property>
      <name>dfs.client.read.shortcircuit</name>
      <value>true</value>
    </property>
    <property>
      <name>dfs.domain.socket.path</name>
      <value>/var/run/hdfs-sockets/dn</value>
    </property>
    <!-- 选择磁盘策略 -->
    <property>
      <name>dfs.datanode.fsdataset.volume.choosing.policy</name>
      <value>org.apache.hadoop.hdfs.server.datanode.fsdataset.AvailableSpaceVolumeChoosingPolicy</value>
    </property>
</configuration>
```

若需要设置Namenode和Datanode的堆大小，可在hadoop-env.sh中设置。

#### 配置用户免密登录 localhost

切换到当前用户，执行如下命令：
```
$ ssh-keygen -t dsa
$ cat ~/.ssh/id_dsa.pub >> ~/.ssh/authorized_keys
$ chmod 0600 ~/.ssh/authorized_keys
``

#### 格式化HDFS文件系统  
在使用Hadoop，先格式化一个新的HDFS安装。输入命令`hdfs namdenode -format`即可。

#### 启动HDFS守护进程

输入命令 `sbin/start-dfs.sh`启动。

可以使用`jps`查看启动的进程。如下：

```
% jps
26221 SecondaryNameNode
26577 Jps
25666 NameNode
25910 DataNode
```

在web界面中，输入 http://localhost:50070 可以查看namenode，如果想要停掉守护进程，使用命令`sbin/stop-dfs.sh`。

#### 修改 `$HADOOP_PREFIX/etc/hadoop/mapred-site.xml`

增加如下配置

```
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
</configuration>
```
在该配置文件是，`mapreduce.framework.name` 指定采用的框架名称，默认是将job提交到MRv1的JobTracker端。

#### 修改 `$HADOOP_PREFIX/etc/hadoop/yarn-site.xml`

增加如下配置

```
<configuration>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
</configuration>
```

启动yarn，运行命令`start-yarn.sh`。然后输入`jps`。在浏览器中输入 http://localhost:8088 可以看到管理界面。

#### 运行wordcount

1. 上传文件

```
$ bin/hadoop fs -mkdir /in
$ binhadoop fs -put $HADOOP_PREFIX/test.txt /in
```

2. 执行

```
$ hadoop jar $HADOOP_PREFIX/share/hadoop/mapreduce2/hadoop-mapreduce-examples-2.3.0-cdh5.1.2.jar wordcount /in /out
```

### 全分布模式

这里使用3台机器做测试，如下

hostname | ip
---------|----------
 hadoop-master|10.10.9.52
 hadoop-slave1|10.10.9.54
 hadoop-slave2|10.10.9.60

#### 修改 `/etc/hosts` 

3台机器的 `/etc/hosts` 文件中都添加如下行：

```
10.10.9.52      hadoop-master
10.10.9.54      hadoop-slave1
10.10.9.60      hadoop-slave2
``` 

其实两个 slave 只需要知道 master 的ip就可以了。注意，这一步不能省，因为 hadoop 会将ip 解析成hostname，如果hostname找不到或配置出错，否则会报 `java.net.UnknownHostException`。

#### 配置ssh无密码登录

将master端用户的ssh key放到两个slave端，保证其可以登录。

配置文件仍和伪分布一样。若伪分布配置中使用了 localhost 代替 master ip，在全分布的情况下，需要将其修改过来。删除 `$HADOOP_PREFIX/data/hadoop` 下的目录，另外，复本数从 1 修改为 3。再重新再格式化 namenode, 将之后的命令再重跑一次。

可以使用 `bin/hdfs dfsadmin -report` 查看起来的节点数，也可访问`http://10.10.9.52:50070`查看节点数。

若出现异常情况，可以分别查看master，slave1, slave2端的日志文件。


修改配置
---

Hadoop 的配置可以分为四类：

- 集群(Cluster)
- 服务(Daemon)
- 任务(Job)
- 操作(Individual Operation)


一些命令
---

- 开启debug  
当运行hadoop命令时，若出现报错信息，可以开启调试模式：`export HADOOP_ROOT_LOGGER=DEBUG,console`。关闭调试模式：`export HADOOP_ROOT_LOGGER=INFO,console`。

参考
---
- [Hadoop: Setting up a Single Node Cluster.](https://hadoop.apache.org/docs/r2.7.3/hadoop-project-dist/hadoop-common/SingleCluster.html)
- [core-default.xml](https://hadoop.apache.org/docs/r2.7.3/hadoop-project-dist/hadoop-common/core-default.xml)
