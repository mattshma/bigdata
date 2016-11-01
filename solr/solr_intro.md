# solr简介

## SolrCloud搭建

### 安装
- 下载solr-5.5.3.tgz
- 从压缩包中解压出安装脚本：`tar xvzf solr-5.5.3.tgz solr-5.5.3/bin/install_solr_service.sh`。
- 执行安装脚本安装：`bash solr-5.5.3/bin/install_solr_service.sh solr-5.5.3.tgz -d /data/solr -u solr`。


### 配置
从solr5.0开始，默认不再提供支持tomcat类似容器的WAR包了。见[Running Solr on Tomcat](https://cwiki.apache.org/confluence/display/solr/Running+Solr+on+Tomcat)说明。所以这里直接使用solr自带的Jetty进行solrcloud的安装，而非Tomcat。

新建目录`mkdir /var/run/solr`，修改属组为solr，之后会在配置文件中将其设为solr pid目录。

修改/opt/solr/bin/solr.in.sh文件，做如下修改：
```
# 注释该行
# SOLR_HEAP="512m"
# 设置内存大小
SOLR_JAVA_MEM="-Xms10g -Xmx10g"
# 设置ZK_HOST后，即开启SolrCloud模式
ZK_HOST=bd01-002.yzdns.com,bd01-002.yzdns.com,bd01-003.yzdns.com
# 设置SOLR_HOST，否则默认为localhost
SOLR_HOST="bd01-001.yzdns.com"
# 设置时区
SOLR_TIMEZONE="Asia/Shanghai"
# 设置pid文件
SOLR_PID_DIR=/var/run/solr
# 设置solr目录
SOLR_HOME=/data/solr/data
# 设置log4j配置文件
LOG4J_PROPS=/data/solr/log4j.properties
# 设置solr log文件
SOLR_LOGS_DIR=/data/solr/logs
```

编辑`/etc/init.d/solr`，修改如下：
```
SOLR_ENV="/opt/solr/bin/solr.in.sh"
```

对于多个solr，配置拷贝过去，修改`SOLR_HOST`即可。

### 启动服务
使用`service solr start`即可启动solr服务。在浏览器中打开 solr地址:2181 即可看到。其他机器上的solr依此类推。

在solr admin中，在 Cloud --> Tree --> /live_nodes 中可以查看到当前所有正常的solr节点。


## 操作collection

对于StandAlone模式，配置文件在本地即可。但对于SolrCloud模式，需将collection对应的配置文件上传到zookeeper中，然后才能执行增删改的操作。对于创建和删除collection，有两种方式：命令行`solr create/delete`和uri rest api的方式。

###  新建
使用命令`bin/solr create -c mycollection -d data_driven_schema_configs -shards 3 -replicationFactor 2`。该命令会自动上传一份`server/solr/configsets/data_driven_schema_configs`到zookeeper中，不需要手动上传。

若使用rest api的方式，则需先通过solr自带的zkcli.sh脚本上传配置文件：

```
# bash server/scripts/cloud-scripts/zkcli.sh -cmd upconfig -z localhost:2181 -n test_conf -d server/solr/configsets/sample_techproducts_configs/
```

然后进行关联：

```
# bash server/scripts/cloud-scripts/zkcli.sh -z localhost:2181 -cmd linkconfig -c test -n test_conf
```

然后通过命令行或者rest api创建即可。
```
# solr create -c test -n test_conf
```

### 删除
如删除test这个collection，可在调用`admin/collections?action=DELETE&name=test`。

## 错误

### This account is currently not available 
创建solr用户时，其shell配置为`/sbin/nologin`，即不能使用shell，编辑`/etc/passwd`，将solr的shell配置修改为`/bin/bash`。

### Error loading solr config from
报错：
`new_core: org.apache.solr.common.SolrException:org.apache.solr.common.SolrException: Could not load conf for core new_core: Error loading solr config from server/solr/new_core/conf/solrconfig.xml`

操作如下：
```
mkdir server/solr/new_core
echo "name=new_core" > server/solr/new_core/core.properties
cp -r server/solr/configsets/basic_configs/conf server/solr/new_core
```

重启solr即可。

### Unsupported major.minor version 52.0
当前java版本为7。下载solr6.2.0安装，报错如下：

```
cannot open `/XXXX/solr/server/logs/solr.log' for reading: No such file or directory
```

查看server/logs/solr-8983-console.log，报错如下：
```
Exception in thread "main" java.lang.UnsupportedClassVersionError: org/eclipse/jetty/start/Main : Unsupported major.minor version 52.0
```
很明显，编译时使用了Java8。需要将当前Java7升级到Java8，或者降低Solr版本，为和其他服务环境一致，于是降Solr版本，考虑到solr各版本情况：

Version |  Description
--------|---------------
4.0.0  | Java 6以上，Zookeeper3.3.6
5.0.0  | Java 7以上，Jetty 8.1.10
6.0.0  | Java 8以上，Jetty 9.3.8


## 参考

- [Taking Solr to Production](https://cwiki.apache.org/confluence/display/solr/Taking+Solr+to+Production)
- [Command Line Utilities](https://cwiki.apache.org/confluence/display/solr/Command+Line+Utilities)
