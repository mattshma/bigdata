# Sqoop简介

[Sqoop](http://sqoop.apache.org/)是一个用于关系型数据库和Hadoop之间互相导入导出的工具。将关系型数据库中的数据导入到Hive或者HBase是比较常见的需求。这里稍微总结下。

## 命令说明

通过help可查看sqoop支持的命令：

```
# sqoop help
16/02/16 14:48:02 INFO sqoop.Sqoop: Running Sqoop version: 1.4.4-cdh5.1.4
usage: sqoop COMMAND [ARGS]

Available commands:
  codegen            Generate code to interact with database records
  create-hive-table  Import a table definition into Hive
  eval               Evaluate a SQL statement and display the results
  export             Export an HDFS directory to a database table
  help               List available commands
  import             Import a table from a database to HDFS
  import-all-tables  Import tables from a database to HDFS
  job                Work with saved jobs
  list-databases     List available databases on a server
  list-tables        List available tables in a database
  merge              Merge results of incremental imports
  metastore          Run a standalone Sqoop metastore
  version            Display version information
```

而细看某命令如import的使用方式，可使用`sqoop help import`来查看。

几个比较通用的选项如下：

- --connect      
通过jdbc指定关系型数据库的地址。

- --direct        
除了通过jdbc导入导出数据外，sqoop还支持使用关系型数据库自身提供的导入导出工具这种direct模式，如mysql中的mysqldump。direct模式需要关系型数据库相关命令如`mysqldump`, `mysqlimport`在运行sqoop命令的用户的path中。一般通过direct模式的效率都比jdbc高。但sqoop模式可能会不支持部分属性，如mysql中direct模式不支持`BLOB`, `CLOB`, `LONGVARBINARY`这些类型字段的导出，且不支持视图。
 
- --username    
连接关系型数据库的用户名。

- --password     
连接关系型数据库的密码。

- --table          
关系型数据库的目标表。

- -m,--num-mappers            
并行执行的任务数，当数据量比较大时使用。

- --warehouse-dir       
hdfs中目标目录的父目录。

- -z,--compress      
开启压缩。

- --compression-codec       
压缩使用的编码解码器。如`--compression-codec "com.hadoop.compression.lzo.LzopCodec"`。 

## Mysql数据导入Hive

一些选项如下：

从关系型数据库导数据到Hadoop中使用sqoop import这条命令，若源mysql的机器ip为192.168.1.2 ，用户名为readonly，密码为pass，库名为test_db，表名为mytable，则可使用如下方式导入到hive中：

```
sqoop import --connect jdbc:mysql://192.168.1.2/test_db --username readonly --password pass --table mytable --hive-import --hive-overwrite --create-hive-table --hive-database test --warehouse-dir /user/hive/warehouse --null-string '\\N' --null-non-string '\\N'
```

以下点注意：

- 数据导入hive后，字段间分隔符默认为`\01`。
- 若不指定`--warehouse-dir`或`--target-dir`，数据会导入到该用户目录下。
- 若导入到hive中的表名与mysql中表名不同，可通过`--hive-table`来指定导入到hive的表名。`--hive-table`可指定为`database.table`的形式。
- Sqoop 默认地导入NULL为 null 字符串，这样当处理NULL类型时，若条件为`IS NOT NULL`，则查询结果会不正确。hive 使用`\N`去标识空值（NULL），另外由于sqoop会根据这些参数来生成代码，所以`\N`需转义为`\\N`，即`sqoop import  ... --null-string '\\N' --null-non-string '\\N'`。

## 多个表导入Hive
`sqoop-import`支持增量导表，若要将多个表结构相同的表导入到Hive，可使用`--append`导入。`--append`还适用分次导表的情况，如第一次根据`where`条件导入表A的一部分数据后，第二次再根据`where`条件`--append`数据到hive表中。

## 库中所有表导入Hive
若要导入某一数据库中的所有表，可使用`sqoop import-all-tables`，`import-all-tables`与`import`命令基本相同。其导入多个表到HDFS/hive中，生成表与导入表是1对1的关系，所以不能指定`--hive-table`，否则只能导入第一个表；若不需要导入某些表，可使用`--exclude-tables`来排除这些表，表名以`,`分割，`,`前后不能有空格，否则报错。用法如`--exclude-tables a,b,c`。 `import-all-tables`不支持`--append`参数，因此若需要将多个关系型数据库中的表导入Hive中的某个表，需要使用`sqoop import`。

## 多个库导入Hive
若关系型数据库被分为多个库，现需要导入到Hive，可通过Hive分区的形式导入多个库：每个库对应一个分区，每个分区内通过`sqoop import-all-tables`或`sqoop import --append`导入。

## 根据查询条件导入数据
几个参数如下：

- --where      
根据where条件判断哪些记录可以被导入到hdfs，如`--where "id>400"`。

- --columns        
导入哪些列到hdfs中。sqoop根据其生成的语句为`SELECT <column list> FROM <table name>`。

## 压缩
若需要使用压缩需指定`--compress`或`-z`和`--compression-codec`，如使用Snappy压缩：`--compression-codec org.apache.hadoop.io.compress.SnappyCodec`。


## 参考
- [Sqoop User Guide](https://sqoop.apache.org/docs/1.4.6/SqoopUserGuide.html)
