使用Maven构建hadoop项目
===

用Maven创建一个Java项目
---

- 创建项目骨架

```
mvn archetype:generate -DgroupId=hadoop.example -DartifactId=wordcount -DinteractiveMode=false
```

增加 hadoop 依赖
---

编辑 pom.xml，内容如下

```
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>hadoop.example</groupId>
  <artifactId>wordcount</artifactId>
  <packaging>jar</packaging>
  <version>1.0-SNAPSHOT</version>
  <name>wordcount</name>
  <url>http://maven.apache.org</url>
  <dependencies>
    <dependency>
      <groupId>junit</groupId>
      <artifactId>junit</artifactId>
      <version>3.8.1</version>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>org.apache.hadoop</groupId>
      <artifactId>hadoop-client</artifactId>
      <version>2.3.0</version>
      <scope>provided</scope>
    </dependency>
    <dependency>
      <groupId>org.apache.mrunit</groupId>
      <artifactId>mrunit</artifactId>
      <version>1.0.0</version>
      <classifier>hadoop2</classifier>
    </dependency>
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-compiler-plugin</artifactId>
        <version>3.1</version>
        <configuration>
          <source>1.7</source>
          <target>1.7</target>
        </configuration>
      </plugin>
    </plugins>
  </build>

  <repositories>
    <repository>
      <id>mavenCentral</id>
      <url>http://repo1.maven.org/maven2/</url>
    </repository>
  </repositories>
</project>

```

生Jar包
---

```
$ mvn clean install
```

运行
---
新建一个txt文件，内容如下：
```
This is a test file!

The world is wonderful~!

This text was created by mingma.
```

运行如下命令
```
$ cd $HADOOP_PREFIX
$ bin/hdfs dfs -mkdir /in
$ bin/hdfs dfs -put test.txt /in
$ bin/hadoop jar wordcount/target/wordcount-1.0-SNAPSHOT.jar hadoop.example.WordCount /in /out
$ bin/hdfs dfs -ls /out
Found 2 items
-rw-r--r--   2 root supergroup          0 2014-09-24 21:34 /out/_SUCCESS
-rw-r--r--   2 root supergroup        100 2014-09-24 21:34 /out/part-r-00000
$ bin/hdfs dfs -cat /out/part-r-00000
    2
The 1
This    2
a   1
by  1
created 1
file!   1
is  2
mingma. 1
test    1
text    1
was 1
wonderful~! 1
world   1
```

运行成功。

遇到的问题：

1. generics are not supported in -source 1.3  
 参考： [Maven : generics are not supported in -source 1.3](http://www.mkyong.com/maven/maven-generics-are-not-supported-in-source-1-3/)

2. 报如下错误：

```
[INFO] -------------------------------------------------------------
[ERROR] /root/program/wordcount/src/main/java/hadoop/example/WordCountReducer.java:[11,33] error: cannot find symbol

[ERROR]  class WordCountReducer
/root/program/wordcount/src/main/java/hadoop/example/WordCount.java:[9,45] error: cannot find symbol

[ERROR]  package org.apache.hadoop.mapreduce.lib.output
/root/program/wordcount/src/main/java/hadoop/example/WordCount.java:[14,1] error: cannot find symbol

...

```

升级 `maven-compiler-plugin`, 参考 [maven “cannot find symbol” message unhelpful](http://stackoverflow.com/questions/14164386/maven-cannot-find-symbol-message-unhelpful/18560198#18560198)。

参考
---

- [Hadoop: Setup Maven project for MapReduce in 5mn](http://hadoopi.wordpress.com/2013/05/25/setup-maven-project-for-hadoop-in-5mn/)
- Hadoop Api

