Hadoop 安装手册
===

前言
---

在安装前，可以看下系统要求，见[JAVA JDK](http://www.cloudera.com/content/cloudera-content/cloudera-docs/CDH5/latest/CDH5-Requirements-and-Supported-Versions/cdhrsv_jdk.html)

Hadoop有三种安装模式：单机模式（Standalone Mode）, 伪分布模式（Pseudo-Distributed Mode）, 全分布模式（Fully Distributed Mode）。

单机模式为Hadoop默认模式。当解压hadoop的tarbal后，3个XML文件均为空文件，当这3个文件均为空文件时，Hadoop会完全运行在本地。单机模式下Hadoop不会使用HDFS，也不会加载Hadoop的守护进程。伪分布模式即所有结点都运行在同一台机器上。而全分布模式即结点在Hadoop集群中。

安装Hadoop
----

### 安装CDH 5 "1-click Install"  

下载"1-click Install"，地址[http://archive.cloudera.com/cdh5/one-click-install/wheezy/amd64/cdh5-repository_1.0_all.deb](Wheezy cdh5-repository_1.0_all.deb)，并安装：`sudo dpkg -i cdh5-repository_1.0_all.deb`。

### 安装`Repository key`  

命令如下：`curl -s http://archive.cloudera.com/cdh5/debian/wheezy/amd64/cdh/archive.key | sudo apt-key add -`。

### 配置JAVA_HOME，HADOOP_PREFIX

在shell中输入`vim ~/.zshrc`后，增加如下行。

```
HADOOP_PREFIX=$HOME/software/hadoop-2.3.0-cdh5.1.2
PATH=$PATH:$HADOOP_PREFIX/bin:$HADOOP_PREFIX/sbin
export $HADOOP_PREFIX $PATH
```

然后`source ~/.zshrc`。

在 `$HADOOP_PREFIX/etc/hadoop/hadoop-env.sh` 中，添加 JAVA_HOME 目录:`export JAVA_HOME=$HOME/software/jdk1.7`。

在修改配置前，若 `$HADOOP_PREFIX/lib/native` 中没有任何.so文件，或者64位系统中.so文件为32位的，需要先编译hadoop。在编译之前，需安装如下包:

- maven
- gcc,g++
- cmake
- zlib-dev
- libssl-dev
- protobuf
  download url: [Protobuf](https://code.google.com/p/protobuf/downloads/list)
  安装好之后，在`.bashrc`中设置 `export LD_LIBRARY_PATH=/usr/local/lib/`。然后`source .bashrc`。

运行`mvn package -Pdist,native -Dskiptests -Dtar`生成hadoop相关的一些so文件。然后将`src/hadoop-dist/target/hadoop-2.3.0-cdh5.1.2/lib/native`中的文件copy到lib/native目录下即可。

再分别说下3种模式的配置情况

单机模式
---

单机模式不需要进行任何配置。此时直接运行Hadoop，如下

```
hadoop jar $HADOOP_PREFIX/share/hadoop/mapreduce2/hadoop-mapreduce-examples-2.3.0-cdh5.1.2.jar wordcount $HADOOP_PREFIX/etc/hadoop wordcount_output
```

伪分布模式
---

### 修改 `$HADOOP_PREFIX/etc/hadoop/hadoop-env.sh`

增加如下配置：

```
export JAVA_HOME=/root/software/jdk1.7.0_67

export HADOOP_PREFIX=/root/software/hadoop-2.3.0-cdh5.1.2
```

### 修改 `$HADOOP_PREFIX/etc/hadoop/core-site.xml`

增加如下配置  

```
<configuration>
    <!-- 设置nameserive -->
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://my_nameservice</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>file:///opt/hadoop/data/hadoop/tmp</value>
    </property>
   <!-- 添加lzo等-->
    <property>
        <name>io.compression.codecs</name>
        <value>org.apache.hadoop.io.compress.DefaultCodec,com.hadoop.compression.lzo.LzopCodec,org.apache.hadoop.io.compress.GzipCodec,org.apache.hadoop.io.compress.BZip2Codec,org.apache.hadoop.io.compress.DeflateCodec,org.apache.hadoop.io.compress.SnappyCodec,org.apache.hadoop.io.compress.Lz4Codec</value>
    </property>
    <!--  设置http user为yarn，用以查看日志 -->
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


`fs.defaultFS` 用于设置hadoop的默认文件系统，文件系统由URI指定。HDFS的守护进程通过该属性来确定HDFS的namenode和端口（默认端口是8020）。注意slave节点中，这里不要填localhost，否则找不到master。

在 $HADOOP_PREFIX 目录下，新建 `/data/hadoop/tmp` 目录用来存放数据。

### 修改 `$HADOOP_PREFIX/etc/hadoop/hdfs-site.xml`

增加如下配置  

```
<configuration>
    <property>
      <name>dfs.nameservices</name>
      <value>youzu-spark</value>
    </property>
    <property>
      <name>dfs.namenode.name.dir</name>
      <value>file:///data/dfs/nn</value>
    </property>
    <property>
      <name>dfs.datanode.data.dir</name>
      <value>file:///data/dfs/dn</value>
    </property>
    <property>
      <name>dfs.journalnode.edits.dir</name>
      <value>file:///data/dfs/jn</value>
    </property>
    <property>
      <name> dfs.namenode.checkpoint.dir</name>
      <value>file:///hadoop/dfs/snn</value>
    </property>
    <property>
      <name>dfs.replication</name>
      <value>3</value>
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

### 格式化HDFS文件系统  
在使用Hadoop，先格式化一个新的HDFS安装。输入命令`hadoop namdenode -format`即可。

### 启动HDFS守护进程

输入命令 `sbin/start-dfs.sh`启动。

可以使用`jps`查看启动的进程。如下：

```
% jps
26221 SecondaryNameNode
26577 Jps
25666 NameNode
25910 DataNode
```

在web界面中，输入 http://localhost:50070 可以查看namenode，如果想要停掉守护进程，使用命令`stop-dfs.sh`。

### 修改 `$HADOOP_PREFIX/etc/hadoop/mapred-site.xml`

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

### 修改 `$HADOOP_PREFIX/etc/hadoop/yarn-site.xml`

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

### 运行wordcount

1. 上传文件

```
$ bin/hadoop fs -mkdir /in
$ binhadoop fs -put $HADOOP_PREFIX/test.txt /in
```

2. 执行

```
$ hadoop jar $HADOOP_PREFIX/share/hadoop/mapreduce2/hadoop-mapreduce-examples-2.3.0-cdh5.1.2.jar wordcount /in /out
```

全分布模式
---

这里使用3台机器做测试，如下

hostname | ip
---------|----------
 hadoop-master|10.10.9.52
 hadoop-slave1|10.10.9.54
 hadoop-slave2|10.10.9.60

### 修改 `/etc/hosts` 

3台机器的 `/etc/hosts` 文件中都添加如下行：

```
10.10.9.52      hadoop-master
10.10.9.54      hadoop-slave1
10.10.9.60      hadoop-slave2
``` 

其实两个 slave 只需要知道 master 的ip就可以了。注意，这一步不能省，因为 hadoop 会将ip 解析成hostname，如果hostname找不到或配置出错，否则会报 `java.net.UnknownHostException`。

### 配置ssh无密码登录

将master端用户的ssh key放到两个slave端，保证其可以登录。

配置文件仍和伪分布一样。若伪分布配置中使用了localhost代替master ip，在全分布的情况下，需要将其修改过来。删除 `$HADOOP_PREFIX/data/hadoop` 下的目录，重新再格式化 namenode, 将之后的命令再重跑一次。

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
- [Installing CDH 5](http://www.cloudera.com/content/cloudera-content/cloudera-docs/CDH5/latest/CDH5-Installation-Guide/cdh5ig_cdh5_install.html)
- [Installing CDH 5 with YARN on a Single Linux Node in Pseudo-distributed mode](http://www.cloudera.com/content/cloudera-content/cloudera-docs/CDH5/latest/CDH5-Quick-Start/cdh5qs_yarn_pseudo.html)
- [install hadoop on ubuntu](http://www.elcct.com/installing-hadoop-2-3-0-on-ubuntu-13-10/)

