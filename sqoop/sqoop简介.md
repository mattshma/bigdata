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

- --connect <jdbc-uri>    
通过jdbc指定关系型数据库的地址。

- --direct      
除了通过jdbc导入导出数据外，sqoop还支持使用关系型数据库自身提供的导入导出工具这种direct模式，如mysql中的mysqldump。direct模式需要关系型数据库相关命令如`mysqldump`, `mysqlimport`在运行sqoop命令的用户的path中。一般通过direct模式的效率都比jdbc高。但sqoop模式可能会不支持部分属性，如mysql中direct模式不支持`BLOB`, `CLOB`, `LONGVARBINARY`这些类型字段的导出，且不支持视图。

- --username <username>    
连接关系型数据库的用户名。

- --password <password>    
连接关系型数据库的密码。

- --table <table-name>       
关系型数据库的目标表。

- -m,--num-mappers <n>        
并行执行的任务数，当数据量比较大时使用。

- --target-dir <dir>   
hdfs中的目标目录。

- --warehouse-dir <dir>   
hdfs中目标目录的父目录。

- --where <where clause>   
根据where条件判断哪些记录可以被导入到hdfs，如`--where "id>400"`。

- --columns <col,col,col...>   
导入哪些列到hdfs中。sqoop根据其生成的语句为`SELECT <column list> FROM <table name>`。

- -z,--compress   
开启压缩。

- --compression-codec <codec>   
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


## 参考
- [Sqoop User Guide](https://sqoop.apache.org/docs/1.4.6/SqoopUserGuide.html)
