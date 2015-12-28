storm单机安装及运行
===

Installation
---
storm需要先安装以下工具：

- python
- zookeeper
- zeromq
- jzmq
- storm

安装好以上工具之后，在bash中设置storm、zookeeper的环境。然后修改storm和zookeeper的配置文件。

- zookeeper  

```
zookeeper$ cp conf/zoo_sample.cfg conf/zoo.cfg
```
- storm  
修改storm.yaml文件：

```java
storm.zookeeper.servers:
 - "127.0.0.1"

nimbus.host: "192.168.188.33"
topology.debug: true
```

Run
---
### zookeeper

启动zookeeper，并查看状态

```
zookeeper$ bin/zkServer.sh start
zookeeper$ bin/zkServer.sh status
JMX enabled by default
Using config: /home/lucky/software/zookeeper-3.4.6/bin/../conf/zoo.cfg
Mode: standalone
```

### 启动storm
启动storm的nimbus, supervisor和ui.

```java
storm$ storm nimbus &
storm$ storm supervisor &
storm$ storm ui &
```

在浏览器上打开`localhost:8080`可以看到UI状态。

由此storm单机安装完成。

maven运行storm-starter
---
在运行之前，需要安装mvn，mvn相关见[maven](https://github.com/beitian/docs/blob/master/java/maven.md).接着操作如下：

```
$ https://github.com/apache/incubator-storm
$ cd incubator-storm/examples/storm-starter
$ mvn package
```

可以见到`storm-starter/target`目录下已生成需要的jar包。接下来用storm运行生成的jar包。

```java
$ cd target
$ storm jar storm-starter-0.9.2-incubating-SNAPSHOT.jar  storm.starter.WordCountTopology WordCount_test
```

可以在浏览器(UI)中看到该topology。

IntelliJ IDEA运行storm-starter
---
按照[using storm-starter with IDEA](https://github.com/apache/incubator-storm/tree/master/examples/storm-starter#using-storm-starter-with-intellij-idea)导入storm-start之后，还**需要导入storm的jar包**，才可以运行WordCountTopology。

Reference List
---
- [Command line client](https://github.com/nathanmarz/storm/wiki/Command-line-client)
- [storm-start](https://github.com/apache/incubator-storm/tree/master/examples/storm-starter)
