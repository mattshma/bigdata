# Hive迁移

由于机房搬迁，现需要将整个Hadoop集群搬迁，这里只说下Hive相关数据的迁移。

## `/user/hive/warehouse`数据迁移

整个集群大小约为1PB，带宽为1Gbps，机器10台。在短短20天，不可能将所有数据copy完成，所以在迁移这部分数据时，分成2部分进行迁移的：小目录（小于1TB）整个目录拷贝，大目录（大目录基本都是每天或每小时生成数据，才会导致目录巨大）根据业务需求按天拷贝。拷贝两边都是webhdfs协议。另外，在拷贝过程中，可指定map结果压缩等来加快拷贝过程。


## Hive metastore
数据拷贝完成后，接下来需要拷贝hive的元数据，这里说下元数据迁移的几种方法：1) 如果是hive同版本拷贝元数据，通过mysqldump导出数据，然后直接再导入到目标mysql服务即可；2）如果源集群使用的是cloudera enterpress版本，可通过其提供的hive复制功能来拷贝；3）如果是hive升级的话，可通过`schematool`或升级脚本来升级；4）如果是迁移集群且hive跨版本的话，若hive数据量比较小，可直接在目标mysql中新建表，然后load数据；5）如果迁移集群且跨版本的话，hive表结构又非常多，可先通过mysqldump导出源metastore相关数据，然后导入到目标mysql中，接着在目标mysql中运行升级脚本。

注意：不管以上哪种方法，在目标集群`source`数据前，最好将其上的相关数据及表结构备份下来！这一步很重要，若升级失败，可通过备份数据回滚。

hive升级脚本一般位于`/opt/cloudera/parcels/CDH/lib/hive/scripts`中。相关方法见README。

若跨版本时，只导入数据而没有运行升级脚本的话，会报错`MetaException(message:Hive Schema version 1.1.0 does not match metastore's schema version 0.12.0 Metastore is not upgraded or corrupt)`，hiveserver2也无法正常运行。运行升级脚本后即可。

## Hue

在Hue中可查看hive metastore元数据是否导入正常。

## 权限

成功导入后，后续还需要对hive权限控制起来。可通过acl来操作。
