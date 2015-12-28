集群Namenode切换方案
====

环境：CDH4.5  
目标：nn1(active), nn2(standby) --> nn1-alt(active), nn2(standby)。  

过程
---
*注：以下操作均在 Cloudera Manager 的HDFS页中完成。*

1. 备份HDFS, HIVE元数据。(脚本备份&&mysql停slave)
2. 配置NameService (30s)   
   在 HDFS 的 Configuration 中，搜索 `nameservice`， 修改`NameNode Nameservice` 和 `SecondaryNameNode Nameservice`的值，使两个值相同。
3. 停HA (4min)   
在 HDFS 的 Instances 中，点击 `Federation and High Availability` 中的 `Actions` 按钮，选择 `Disable High Availability`，选择nn2为namenode，随机选择一个节点做SecondaryNameNode Host.     
*注：若依赖HDFS的部分组件重启失败，则需要手动重启，同时再发布下客户端的配置。*   
4. 若节点A之前是JournalNode，第二次仍选其做JournalNode时，需备份之前JournalNode目录数据，并清空该目录。 
5. 启用HA (6min)   
 - 在 HDFS 的 Instaces 中，点出 Acitons 按钮，选择 `Enable High Availability`
 - 填写 Nameservice Name，为 nameservice1
 - 选择 NameNode Hosts，加上 nn1-alt， 并重新选择 JournalNode Hosts（这里选择和切换前一样多的JournalNode：3个），一直点击Continue，重启集群    
若`Deploy Client Configuration`失败，则手动deploy.    
6. 配置Hue 和 重启 Hive:   
 - For each of the Hive service(s) Hive, stop the Hive service, back up the Hive Metastore Database to a persistent store, run the service command "Update Hive Metastore NameNodes", then restart the Hive services.    
7. Manual Failover (2min)   
在 HDFS 的 Instances 中，点击 `Federation and High Availability` 中的 `Actions` 按钮，选择 `Manual Failover`，选择 nn1-alt 为 namenode.  
8. 检查 HDFS, HBase, Hive etc。

问题
---

- JouralNode 目录清空

若切换前JouralNode在A,B,C三台机器上，切换过程中，指定B,C,D为新的JournalNode，则在启动HA时，需要先清空B,C上JournalNode目录中的数据。在CM5中，会帮助清除该目录，但CM4中需手动清除。

- `/run`目录在被mount时去掉 `noexec` 属性。

新加入集群的NameNode机器报错如下：
```
java.io.IOException: Cannot run program "/run/cloudera-scm-agent/process/5695-hdfs-NAMENODE/topology.py" (in directory "/run/cloudera-scm-agent/process/5695-hdfs-NAMENODE"): java.io.IOException: error=13, Permission denied
```
经发现，`/run`目录下的所有可执行文件都不能以`./script_name`执行(文件有可运行权限)，经查明，`/run`目录被mount时，带有`noexec`，而CM4和对应Ubuntu有bug，导致`topology.py`无法运行，机架位置获取不到，产生这个问题。重新mount去掉该属性即可解决这个问题：`mount -o remount,exec /run`。


