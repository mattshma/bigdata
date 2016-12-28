# Spark On Yarn搭建

## 背景
CDH提供的Spark太低，由于业务需求，需要安装Spark2.0，这里记录下整个过程。由于使用的是Spark On Yarn，所以这里Hadoop直接使用CDH版本，方便安装。

## 过程
### 准备
在正式安装前，需优化操作系统，如下
- /etc/hosts       
  hdfs所有机器列表。
- 安装lzo-devel & lzop      
  添加lzo压缩。
- swappiness        
  在/etc/sysctl.conf中设置`vm.swappiness = 1`。
- 关闭透明大页(transparent hugepage)的compaction操作    
  在/etc/rc.local中添加`echo never > /sys/kernel/mm/redhat_transparent_hugepage/defrag`。
- 关闭SELinux和iptables              
- 拷贝`mysql-connector-java.jar`到`/usr/share/java`目录
- 设置/etc/security/limits.d/90-nproc.conf        
  如下：        
  ```
  *    -    nproc     65535
  *    -    nofile    65535
  ```
- 设置/etc/ntp.conf             
  如下是一个sample：
  ```
  driftfile /var/lib/ntp/drift
  
  restrict default kod nomodify notrap nopeer noquery
  restrict -6 default kod nomodify notrap nopeer noquery
  restrict 127.0.0.1
  restrict -6 ::1 
  
  server <ntp_server1> prefer
  server <ntp_server1> iburst
  server <ntp_server2> iburst
  server 0.centos.pool.ntp.org iburst
  
  server 127.127.1.0     # local clock
  fudge  127.127.1.0 stratum 10
  
  restrict 10.0.0.0 mask 255.0.0.0 nomodify
  ```
- 安装MySQL    
  过程如下：
```
shell> useradd mysql
shell> tar zxvf /path/to/mysql-VERSION-OS.tar.gz -C /opt
shell> ln -s /opt/mysql-VERSION-OS mysql
shell> cd /opt
shell> chown -R mysql:mysql mysql
shell> cd mysql
# mysql.cnf自定义好
shell> cp support-files/my-medium.cnf /etc/my.cnf
shell> scripts/mysql_install_db --user=mysql
shell> bin/mysqld_safe --user=mysql &
# Next command is optional
shell> cp support-files/mysql.server /etc/init.d/mysqld
shell> /opt/mysql//bin/mysqladmin -u root password 'new-password'
```
进入mysql中，设置root密码，并删除密码为空的帐号，添加用户，如hadoop用户：
```
mysql> create user hadoop identified by 'hadoop';
mysql> create database hive;
mysql> grant all privileges on hive.* to hadoop@'%' identified by 'hadoop';
mysql> flush privileges;
```

### 安装cloudera
在机器A上安装执行`cloudera-manager-installer.bin`后，安装cloudera-manager-server后，为其设置数据库，默认为自带的pg，正式环境中，需要其替换掉，这里以MySQL为例，说下过程。

- 在MySQL中建立scm的库，用户名，然后执行`/usr/share/cmf/schema/scm_prepare_database.sh -h <MySQL_ip> mysql <DB> <Username> <Password>`，执行完后，在`/etc/cloudera-scm-server/db.properties`中可以看到信息，执行`/etc/init.d/cloudera-scm-server restart`。

- 在浏览器中输入 http://<A_ip>:7180，选择Cloudera Express版本。然后一步步安装即可。

### 配置调优
#### HDFS
- 添加lzo压缩。        
  `io.compression.codecs`添加`com.hadoop.compression.lzo.LzopCodec`。
- 开启trash功能。      
  `fs.trash.interval`调整为7天。
- core-site.xml添加配置。    
  如下：
 ```
 <property>
   <name>hadoop.http.staticuser.user</name>
   <value>yarn</value>
 </property>
 ```
- balancer调优。    
  hdfs-site.xml添加如下内容：
  ```
  <property>
    <name>dfs.datanode.balance.max.concurrent.moves</name>
    <value>100</value>
  </property>
  ```
  `dfs.balance.bandwidthPerSec`调整为100MB。
- `dfs.namenode.handler.count`，`dfs.namenode.service.handler.count`和`dfs.datanode.handler.count`调大。
- 开启shortcircuit。
- `dfs.datanode.max.xcievers`调整为10240。
- NameNode和DataNode JVM HEAP调整。
- 开启HA。

#### YARN
- `yarn.admin.acl`设置为`hdfs,yarn`。
- `io.file.buffer.size`设置为128。
- `mapreduce.task.io.sort.mb`设置为1GB。
- `mapreduce.application.classpath`添加lzo的路径：`mapreduce.application.classpath`添加`/opt/cloudera/parcels/GPLEXTRAS/lib/hadoop/lib/*`。`mapreduce.admin.user.env`添加`/opt/cloudera/parcels/GPLEXTRAS/lib/hadoop/lib/native`。
- 开启uber task：`mapreduce.job.ubertask.enable`开启。
- 设置`yarn.nodemanager.resource.memory-mb`和`yarn.nodemanager.resource.cpu-vcores`。
- 设置`mapreduce.map.memory.mb`，`mapreduce.map.cpu.vcores`，`mapreduce.reduce.memory.mb`和`mapreduce.reduce.cpu.vcores`。
- 设置yarn-site.xml中的`yarn.nodemanager.aux-services`，值为`spark_shuffle,mapreduce_shuffle`，设置`yarn.nodemanager.aux-services.spark_shuffle.class`，值为`org.apache.spark.network.yarn.YarnShuffleService`。
- 开启HA

### 安装spark

如下：
```
# tar xvzf spark-2.0.2-bin-hadoop2.6.tgz -C /opt
# cd /opt
# ln -s spark-2.0.2-bin-hadoop2.6/ spark
```

修改/etc/bashrc，添加如下行：
```
export SPARK_HOME=/opt/spark
export SCALA_HOME=/opt/scala

export PATH=${SPARK_HOME}/bin:$SCALA_HOME/bin:$PATH
```
source该文件使用配置生效。

修改`/etc/spark/conf/spark-default.conf`，如下：
```
spark.eventLog.enabled  true
spark.eventLog.dir      hdfs://realtime/user/spark/applicationHistory
spark.yarn.historyServer.address        <ip_history>:18080
spark.yarn.jars                    hdfs:///user/spark/jars/*.jar
spark.driver.extraClassPath    /opt/cloudera/parcels/GPLEXTRAS/lib/hadoop/lib/hadoop-lzo.jar
spark.driver.extraLibraryPath   /opt/cloudera/parcels/CDH/lib/hadoop/lib/native:/opt/cloudera/parcels/GPLEXTRAS/lib/hadoop/lib/native
spark.executor.extraClassPath    /opt/cloudera/parcels/GPLEXTRAS/lib/hadoop/lib/hadoop-lzo.jar
spark.executor.extraLibraryPath /opt/cloudera/parcels/CDH/lib/hadoop/lib/native:/opt/cloudera/parcels/GPLEXTRAS/lib/hadoop/lib/native
spark.yarn.am.extraLibraryPath  /opt/cloudera/parcels/CDH/lib/hadoop/lib/native:/opt/cloudera/parcels/GPLEXTRAS/lib/hadoop/lib/native
spark.dynamicAllocation.enabled true
spark.shuffle.service.enabled   true
spark.serializer        org.apache.spark.serializer.KryoSerializer
spark.master    yarn
spark.submit.deployMode    client
```

修改`/opt/spark/conf/spark-env.sh`，如下：
```
export HADOOP_HOME=/opt/cloudera/parcels/CDH
export HADOOP_CONF_DIR=/etc/hive/conf
export SPARK_HOME=/opt/spark
export JAVA_LIBRARY_PATH=.:$JAVA_HOME/lib:$HADOOP_HOME/lib/hadoop/native

export SPARK_HISTORY_OPTS="-Dspark.history.fs.logDirectory=hdfs://realtime/user/spark/applicationHistory -Dspark.history.retainedApplications=200"
```

在HDFS上创建history目录和jars目录：
```
# sudo -u hdfs hdfs dfs -mkdir /user/spark/applicationHistory
# sudo -u hdfs hdfs dfs -mkdir /user/spark/jars
# sudo -u hdfs hdfs dfs -chown -R spark:spark /user/spark
# sudo -u hdfs hdfs dfs -chmod 777 /user/spark/applicationHistory
# sudo -u spark hdfs dfs -copyFromLocal jars/* /user/spark/jars
```

启动spark history: `/opt/spark/sbin/start-history-server.sh`。

执行spark-shell，即可进入spark shell。

## 报错
### `The auxService:spark_shuffle does not exist`
Spark shell中报错如下：
```
WARN cluster.YarnScheduler: Initial job has not accepted any resources; check your cluster UI to ensure that workers are registered and have sufficient resources
```

而Job log如下：
```
16/12/26 10:44:56 ERROR yarn.YarnAllocator: Failed to launch executor 2962 on container container_e05_1482486705919_0014_01_002963
org.apache.spark.SparkException: Exception while starting container container_e05_1482486705919_0014_01_002963 on host bd15-122.yzdns.com
    at org.apache.spark.deploy.yarn.ExecutorRunnable.startContainer(ExecutorRunnable.scala:125)
    at org.apache.spark.deploy.yarn.ExecutorRunnable.run(ExecutorRunnable.scala:70)
    at org.apache.spark.deploy.yarn.YarnAllocator$$anonfun$runAllocatedContainers$1$$anon$1.run(YarnAllocator.scala:515)
    at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1110)
    at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:603)
    at java.lang.Thread.run(Thread.java:722)
Caused by: org.apache.hadoop.yarn.exceptions.InvalidAuxServiceException: The auxService:spark_shuffle does not exist
    at sun.reflect.GeneratedConstructorAccessor26.newInstance(Unknown Source)
    at sun.reflect.DelegatingConstructorAccessorImpl.newInstance(DelegatingConstructorAccessorImpl.java:45)
    at java.lang.reflect.Constructor.newInstance(Constructor.java:525)
    at org.apache.hadoop.yarn.api.records.impl.pb.SerializedExceptionPBImpl.instantiateException(SerializedExceptionPBImpl.java:168)
    at org.apache.hadoop.yarn.api.records.impl.pb.SerializedExceptionPBImpl.deSerialize(SerializedExceptionPBImpl.java:106)
    at org.apache.hadoop.yarn.client.api.impl.NMClientImpl.startContainer(NMClientImpl.java:206)
    at org.apache.spark.deploy.yarn.ExecutorRunnable.startContainer(ExecutorRunnable.scala:122)
    ... 5 more
```


参考[Spark Configuration](http://spark.apache.org/docs/latest/job-scheduling.html#configuration-and-setup)，步骤如下：

- 将/opt/spark/yarn目录下的spark-2.0.2-yarn-shuffle.jar拷贝至各nodemanger的/opt/cloudera/parcels/CDH/lib/hadoop-yarn/lib目录下。并删除CDH已有的spark-<version>-cdh<version>-yarn-shuffle.jar文件。对spark-2.0.2-yarn-shuffle.jar做软链，名称为spark-yarn-shuffle.jar。
- 修改yarn-site.xml，添加如下配置：
```
<property>
  <name>yarn.nodemanager.aux-services</name>
  <value>spark_shuffle,mapreduce_shuffle</value>
</property>
<property>
  <name>yarn.nodemanager.aux-services.spark_shuffle.class</name>
  <value>org.apache.spark.network.yarn.YarnShuffleService</value>
</property>
```
- 重启NodeManager即可。

