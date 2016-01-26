HBase 迁移数据
----

因搬迁机房需要，现需要在两个集群间迁移数据。这里记录下。

## 方法
有好几种方法用于不同HBase集群的数据迁移。可以参考[Importing Data Into HBase](http://www.cloudera.com/content/www/en-us/documentation/enterprise/latest/topics/admin_hbase_import.html)。这里大致说下。

- 如果数据是从一个HBase集群导入到另一个HBase集群：
  - 使用`snapshot`和`clone_snapshot`或`ExportSnapshot`方法；或`CopyTable`方法。
  - 若两个集群都不停机，可使用HBase的复制功能。
  - 或两个HBase版本不兼容，可使用DistCP和Import, Export配合迁移数据；或者升级HFile的。
- 若数据是从非HBase导入到HBase集群：
  - 将数据写入HFile格式，然后使用 `BulkLoad` 的导入到HBase。这种方法能绕开写路径，提交效率。
  - 使用pig之类工具将数据导入到HBase集群。 
- 使用流式数据导入到HBase集群：
  - 可以调用Java API或Thrift Proxy API写一个Java工具。
  - 通过REST Proxy API结合`wget`和`curl`将数据直接写入到HBase中。
  - 使用Flume或Spark。

### 使用CopyTable
CopyTable使用HBase的读路径或写路径拷贝当前集群中部分或全部的表到同一个/不同集群中的一个新表中。CopyTable的命令如下：

```shell
$ ./bin/hbase org.apache.hadoop.hbase.mapreduce.CopyTable --help 
Usage: CopyTable [general options] [--starttime=X] [--endtime=Y] [--new.name=NEW] [--peer.adr=ADR] <tablename>
```

若是拷贝到其它集群，指定`--peer.adr`。

因为使用的是读路径和写路径，所以这种方式会引起读写压力。同时会造成切分Region。当然右预先分区来避免过度的切分region。

### 从CDH4拷贝数据到CDH5

CDH4和CDH5是不兼容的，因此`CopyTable`无法成功。可使用如下两种方法:

#### 配合Import和Export使用DistCP

- 在一个集群中，导出数据

```
hbase org.apache.hadoop.hbase.mapreduce.Export <tablename> /export_directory
```

- 将该数据从`/export_directory`拷贝到目标集群上

```
hadoop distcp -p -update -skipcrccheck hftp://cdh4-namenode:port/export_directory hdfs://cdh5-namenode/import_directory
```

默认端口为50070。


- 在目标集群上使用HBase Shell创建新表，表的列族同源集群
- 将目标集群hdfs中新拷贝的表导入到hbase中

```
hbase -Dhbase.import.version=0.94 org.apache.hadoop.hbase.mapreduce.Import t1 /import_directory
```

#### 升级HFile

**注意：这种方法仅当新集群为空时使用！**

- 使用distcp将HFile文件从源集群拷贝至目标集群中
```
hadoop distcp -p -update -skipcrccheck webhdfs://cdh4-namenode:http-port/hbase hdfs://cdh5-namenode:rpc-port/hbase
```

- 在目标集群的CM中，在`Cluster > HBase`的`Action`菜单中选择`Upgrade HBase`.
- 启动目标集群

上述两种方法各有优缺点。前一种方法比较慢，当数据量大时，会耗时很久，后一种方法仅在目标集群为空时使用。

### 使用快照
快照保留的集群某个时间点的快照，同CopyTable/Export等相比，snapshot操作的仅仅是metadata，因此速度非常快。如下。

```
> hbase shell         
# 备份
> snapshot 'TestTable', 'TestTableSnapshot'          
# 使用clone_snapshot将某个表拷贝到同一集群中的其它表中
> clone_snapshot 'TestTableSnapshot', 'NewTestTable'  
```

### 使用BulkLoad
HBase使用HFile格式存储文件，因此可以用程序将数据写成HFile格式，然后批量导入到HBase中。这种方式绕过写路径，有如下好处：

- 导入的数据能立即在HBase中可用，并不会产生额外的load和延迟
- 因为没使用WAL，所以不会触发flush和split操作
- 不会导致大量的GC操作

一般使用BulkLoad的过程如下：

- 从源数据外取出数据。如mysql数据库中使用`mysqldump`命令取出数据。如果数据为TSV或CSV格式，可跳过这步。
- 将第一步产生的数据处理为HFile格式。
- 每个region产生一个HFile文件
- 将HFile文件导入到HBase中

### 使用复制

HBase复制用于不同集群中复制数据，其以主推送的形式进行，即Master向各Slave推送数据。类似Mysql以Binlog进行复制，HBase的复制基于HLog（WAL）。复制是异步的，这意味主集群的修改不能马上在从集群上同步（最终一致性）。

## 实践
在实际情况中，有集群A(0.98)和集群B(1.0)，现需要将集群A中的部分表拷贝到集群B中。

在集群B上的一个Yarn的gateway上执行如下脚本，其中distcp用了压缩。
```ssh
tmpdir="tmp/hbase_migrate"

# ssh到A集群Yarn的gateway上export表
ssh evans@A_GATEWAY_IP:PORT hbase org.apache.hadoop.hbase.mapreduce.Export -Dmapreduce.map.java.opts=-Xmx4g  -Dmapreduce.map.memory.mb=5000 $source_table_name hdfs://A_HDFS_IP:PORT/$tmpdir

# disctp from A to B
HADOOP_USER_NAME=hbase hadoop distcp -Dmapreduce.job.queuename=root.hadoop -Dmapreduce.job.name=hbase.${source_table_name} -update -delete -strategy dynamic -log /user/hbase/_distcplogs/tmp.$(date +%s).$RANDOM -update -delete webhdfs://A_IP:PORT/$tmpdir $tmpdir

# import
HADOOP_USER_NAME=hbase hbase -Dhbase.import.version=0.98 org.apache.hadoop.hbase.mapreduce.Import $source_table_name $tmpdir
```


参考：
---
- [Snapshots](https://hbase.apache.org/book.html#ops.snapshots)
- [distcp](https://hadoop.apache.org/docs/r1.0.4/cn/distcp.html)
- [Online Apache HBase Backups with CopyTable](http://blog.cloudera.com/blog/2012/06/online-hbase-backups-with-copytable-2/)
- [Approaches to Backup and Disaster Recovery in HBase](http://blog.cloudera.com/blog/2013/11/approaches-to-backup-and-disaster-recovery-in-hbase/)
