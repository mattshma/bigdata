Ubuntu 下使用apt安装单机cdh5
===

在安装前确认java，javac等版本是否一致，如果不一致的话，参考[How To Install Java on Ubuntu with Apt-Get](https://www.digitalocean.com/community/tutorials/how-to-install-java-on-ubuntu-with-apt-get)重新安装。

参考[cloudera](http://www.cloudera.com/content/cloudera/en/documentation/core/latest/topics/cdh_ig_cdh5_install.html#topic_4_4_1_unique_2__p_44_unique_2) Ubuntu 安装Hadoop(CDH)，步骤如下：

- 下载 cloudera.list

```
sudo wget http://archive.cloudera.com/cdh5/ubuntu/precise/amd64/cdh/cloudera.list -O /etc/apt/sources.list.d/cloudera.list
```

- 添加key  

```
$ wget http://archive.cloudera.com/cdh5/ubuntu/precise/amd64/cdh/archive.key -O archive.key
$ sudo apt-key add archive.key
```

- 更新源， `sudo apt-get update`

```
sudo apt-get install hadoop-yarn-resourcemanager hadoop-hdfs-namenode hadoop-hdfs-secondarynamenode hadoop-hdfs-datanode hadoop-mapreduce hadoop-client  hadoop-mapreduce-historyserver hadoop-yarn-proxyserver hadoop-client  hadoop-0.20-mapreduce-jobtracker hadoop-0.20-mapreduce-tasktracker
```
- 修改配置

/etc/hadoop/conf/core-site.xml
```
<configuration>
<property>
        <name>fs.defaultFS</name>
        <value>hdfs://localhost:9000</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>/home/hadoop/dfs</value>
    </property>
</configuration>
```

/etc/hadoop/conf/hdfs-site.xml
```
<configuration>
  <property>
     <name>dfs.namenode.name.dir</name>
     <value>/home/hadoop/dfs/nn</value>
  </property>
  <property>
     <name>dfs.datanode.data.dir</name>
     <value>/home/hadoop/dfs/dn</value>
  </property>
</configuration>
```

/etc/hadoop/conf/mapred-site.xml
```
<configuration>
<property>
    <name>mapred.job.tracker</name>
    <value>localhost:9001</value>
</property>
</configuration>
```

- 启动服务
```
sudo service hadoop-hdfs-namenode start
sudo service hadoop-hdfs-datanode start
sudo service hadoop-0.20-mapreduce-jobtracker start
sudo service hadoop-0.20-mapreduce-tasktracker start
```

安装完成。
