# Hive迁移

由于机房搬迁，现需要将整个Hadoop集群搬迁，这里只说下Hive相关数据的迁移。

## `/user/hive/warehouse`数据迁移

整个集群大小约为1PB，带宽为1Gbps，机器10台。在短短20天，不可能将所有数据copy完成，所以在迁移这部分数据时，分成2部分进行迁移的：小目录（小于1TB）整个目录拷贝，大目录（大目录基本都是每天或每小时生成数据，才会导致目录巨大）根据业务需求按天拷贝。拷贝两边都是webhdfs协议。另外，在拷贝过程中，可指定map结果压缩等来加快拷贝过程。


## Hive metastore
数据拷贝完成后，接下来需要拷贝hive的元数据，若不拷贝的话，会出现hdfs有数据，但hive没数据的情况。这里说下元数据迁移的几种方法：1) 如果是hive同版本拷贝元数据，通过mysqldump导出数据，然后直接再导入到目标mysql服务即可；2）如果源集群使用的是cloudera enterpress版本，可通过其提供的hive复制功能来拷贝；3）如果是hive升级的话，可通过`schematool`或升级脚本来升级；4）如果是迁移集群且hive跨版本的话，若hive数据量比较小，可直接在目标mysql中新建表，然后load数据；5）如果迁移集群且跨版本的话，hive表结构又非常多，可先通过mysqldump导出源metastore相关数据，然后导入到目标mysql中，接着在目标mysql中运行升级脚本。

注意：不管以上哪种方法，在目标集群`source`数据前，最好将其上的相关数据及表结构备份下来！这一步很重要，若升级失败，可通过备份数据回滚。

hive升级脚本一般位于`/opt/cloudera/parcels/CDH/lib/hive/scripts`中。相关方法见README。

若跨版本时，只导入数据而没有运行升级脚本的话，会报错`MetaException(message:Hive Schema version 1.1.0 does not match metastore's schema version 0.12.0 Metastore is not upgraded or corrupt)`，hiveserver2也无法正常运行。运行升级脚本后即可。

### 实际操作
- 关掉新老集群的hive，确保hive元数据文件没更新操作。
- 新集群hive metastore mysql备份：`mysqldump -uhadoop -p --databases hive > new_hive_metastore_bak.sql`。
- 老集群hive metastore mysqldump: `mysqldump -udbmanager -p metastore > old_hive_metastore.sql`，将该元数据文件传到新集群hive机器上。
- 老集群hive元数据文件传到新集群后，进入新集群mysql的hive元数据库后，执行该文件`source old_hive_metastore.sql`。
- 升级新集群hive元数据库文件，老集群hive版本为0.13，新集群hive版本为1.1.0，在mysql的元数据库中，执行如下命令:
```
hadoop:hive> source upgrade-0.13.0-to-0.14.0.mysql.sql
+--------------------------------------------------+
|                                                  |
+--------------------------------------------------+
| Upgrading MetaStore schema from 0.13.0 to 0.14.0 |
+--------------------------------------------------+
1 row in set, 1 warning (0.00 sec)
hadoop:hive> source upgrade-0.14.0-to-1.1.0.mysql.sql
+-------------------------------------------------+
|                                                 |
+-------------------------------------------------+
| Upgrading MetaStore schema from 0.14.0 to 1.1.0 |
+-------------------------------------------------+
1 row in set, 1 warning (0.00 sec)
```
- 启动新老集群hive，完成。

## 手动创建分区
在实际迁移过程中，肯定会遇到新集群元数据落后老集群元数据的情况，这时需要针对落后数据做迁移。如果新集群已经在使用了，则不能单纯的使用distcp来进行数据拷贝了。

```
老集群 = 已拷贝数据 + 待拷贝数据
新集群 = 已拷贝数据 + 新写数据。
```

对于差量数据（待拷贝的数据），由于不能覆盖新写数据，需要分情况拷贝：新写数据目录不动，实时写的目录按分区拷贝（如flume写入等），不定时写的目录在特定时间拷贝（即若目录是脚本运行写入，选择脚本运行完成后全量拷贝数据）。若实时目录在按分区拷贝后仍存在差异，则需要考虑将实时业务停掉，再全量拷贝，由于分区拷贝完成，因此差异不会太大，拷贝时间也不会太久，总之，对于新老集群拷贝，尽量在保证数据安全性的情况下做大目录拷贝，而非按分区拷贝。

数据拷贝完成，需要更新差量数据的元数据表，由于新集群数据已有不同于老集群的元数据，因此不能按之前说的方法拷贝，考虑到元数据表依赖复杂，因此最好写脚本手动添加分区。

> 元数据表说明：  
>#### Database
>- DBS    
>用来存储hive中数据库的基本信息。
>
>- DATABASE_PARAMS       
>数据库表的属性参数。
>
>#### Table
>- TBLS      
>hive中表，视图的基本信息。
>
>- TABLE_PARAMS    
>表，视图的属性信息。
>
>#### 数据存储
>- SDS    
>表保存文件存储的基本信息。如INPUT_FORMAT，是否压缩等。
>
>#### 序列化
>- SERDES    
>表存储序列化使用的类信息。
>
>- SERDES_PARAMS     
>存储序列化具体的参数及值
>
>#### 列信息
>- CDS   
>存储数据仓库中的CD_ID，该表只有这一个字段。
>
>- COLUMN_V2    
>存储CD_ID对应的所有字段信息。
>
>#### 分区
>- PARTITIONS   
>存储hive中所有分区信息，查看表分区信息可通过tbl_id来查看。
>
>- PARTITION_KEY_VALS         
>PARTITION_KEY_VALS 存储PARTITION_KEY中描述的分区字段的值，通常配合PARTITIONS 和PARTITION_KEYS表使用。
>
>#### bucket 
>- BUCKETING_COLS     
>所有使用分桶的SDS。
>
>#### 权限相关
>主要包括DB_PRIVS，TBL_PRIVS，PART_PRIVS。
    
## Hue

在Hue中可查看hive metastore元数据是否导入正常。

## 权限

成功导入后，后续还需要对hive权限控制起来。可通过acl来操作。

## 问题
### Invalid partition for table xxx
脚本执行过程中报错如下：
```
FAILED: SemanticException org.apache.hadoop.hive.ql.metadata.HiveException: Invalid partition for table summary_month
```

很明显，分区信息出现错误，随机根据该表分区进行查询，均正常。既然分区异常，所以想到的方法是删除该表所有分区后再新建，结果在删除分区过程，发现一个分区无法删除，查看元数据表。

```
mysql> select * from tbls,dbs where tbl_name='summary_month' and name='dw_119_mdl' and tbls.db_id=dbs.db_id;
+--------+-------------+-------+------------------+------------+-----------+---------+---------------+----------------+--------------------+--------------------+----------------+-------+------+-------------------------------------------------------+------------+------------+------------+
| TBL_ID | CREATE_TIME | DB_ID | LAST_ACCESS_TIME | OWNER      | RETENTION | SD_ID   | TBL_NAME      | TBL_TYPE       | VIEW_EXPANDED_TEXT | VIEW_ORIGINAL_TEXT | LINK_TARGET_ID | DB_ID | DESC | DB_LOCATION_URI                                       | NAME       | OWNER_NAME | OWNER_TYPE |
+--------+-------------+-------+------------------+------------+-----------+---------+---------------+----------------+--------------------+--------------------+----------------+-------+------+-------------------------------------------------------+------------+------------+------------+
|  92882 |  1447725938 | 87883 |                0 | datacenter |         0 | 2284756 | summary_month | EXTERNAL_TABLE | NULL               | NULL               |           NULL | 87883 | NULL | hdfs://youzu-hadoop/user/hive/warehouse/dw_119_mdl.db | dw_119_mdl | NULL       | NULL       |
+--------+-------------+-------+------------------+------------+-----------+---------+---------------+----------------+--------------------+--------------------+----------------+-------+------+-------------------------------------------------------+------------+------------+------------+
1 row in set (0.00 sec)
mysql> select * from partitions where tbl_id=92882;
+---------+-------------+------------------+-------------+---------+--------+----------------+
| PART_ID | CREATE_TIME | LAST_ACCESS_TIME | PART_NAME   | SD_ID   | TBL_ID | LINK_TARGET_ID |
+---------+-------------+------------------+-------------+---------+--------+----------------+
| 4098483 |  1466280995 |                0 | ds=20160618 | 4254915 |  92882 |           NULL |
+---------+-------------+------------------+-------------+---------+--------+----------------+
1 row in set (0.00 sec)
mysql> select * from partition_key_vals where part_id='4098483';
+---------+--------------+-------------+
| PART_ID | PART_KEY_VAL | INTEGER_IDX |
+---------+--------------+-------------+
| 4098483 | 20160618     |           0 |
| 4098483 | 20160601     |           1 |
+---------+--------------+-------------+
2 rows in set (0.00 sec)
```

问题出来了，`partition_key_vals`表一个分区id对应两个val，删除错误的一条记录后，在hive异常分区被删除，重建所有分区，问题解决。

在解决过程中，查看源码，对着源码也可说明解决思路：

[partition代码](https://github.com/apache/hive/blob/26b5c7b56a4f28ce3eabc0207566cce46b29b558/ql/src/java/org/apache/hadoop/hive/ql/metadata/Partition.java#L165)
```
    if (table.isPartitioned()) {
      try {
        if (tPartition.getSd().getLocation() == null) {
          // set default if location is not set and this is a physical
          // table partition (not a view partition)
          if (table.getDataLocation() != null) {
            Path partPath = new Path(table.getDataLocation(), Warehouse.makePartName(table.getPartCols(), tPartition.getValues()));
            tPartition.getSd().setLocation(partPath.toString());
          }
        }
        // set default if columns are not set
        if (tPartition.getSd().getCols() == null) {
          if (table.getCols() != null) {
            tPartition.getSd().setCols(table.getCols());
          }
        }
      } catch (MetaException e) {
        throw new HiveException("Invalid partition for table " + table.getTableName(),
            e);
      }
    }
```
出现异常的点应该在if内部的3条语句中，查看[API](https://hive.apache.org/javadocs/r1.1.1/api/index.html)，只有`Warehouse.makePartName(table.getPartCols(), tPartition.getValues())`会产生`MetaException`的异常，因此问题锁定在这里。查看[makePartName](https://github.com/apache/hive/blob/master/metastore/src/java/org/apache/hadoop/hive/metastore/Warehouse.java#L535)代码：

```
  public static String makePartName(List<FieldSchema> partCols,
      List<String> vals, String defaultStr) throws MetaException {
    if ((partCols.size() != vals.size()) || (partCols.size() == 0)) {
      ...
    }
  }
```
其会比较从tbls表中取出的行数与从partition_key_vals中取出值行数的大小，若不同则抛出异常，佐证了该问题。


