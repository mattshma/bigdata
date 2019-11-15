pom.xml说明
===

The Basics
---
pom.xml存储了一个工程的所有信息和build过程中plugin的配置信息。其中`groupId:artifactId:version`是所有pom.xml的必须字段。`groupId`相当于java的package这个概念。如果`groupId`中有".", 将会被操作系统替换为相应的文件分割符（如Unix系统中被替换成"/"）。`artifactId`是工程的名字，其和`groupId`一起唯一指定了这个工程。`version`是版本信息。这三个字段指出了该工程的指定版本让maven知道谁在处理，何时处理处理这个工程。

POM关系
---
Maven有三种关系：dependencies、inheritance、aggregation

### Dependencies（依赖）
依赖列表是POM的基石。maven将会根据pom文件下载和链接这些依赖。

```java
<project xmlns="http://maven.apache.org/POM/4.0.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
                      http://maven.apache.org/xsd/maven-4.0.0.xsd">
  ...
  <dependencies>
    <dependency>
      <groupId>junit</groupId>
      <artifactId>junit</artifactId>
      <version>4.0</version>
      <type>jar</type>
      <scope>test</scope>
      <optional>true</optional>
    </dependency>
    ...
  </dependencies>
  ...
</project>
```

### exclusions
如果我们不想包括传递依赖，如只想使用maven-core，而不想使用它的依赖，可以把这个文件放到exclusion里面。

```java
<project xmlns="http://maven.apache.org/POM/4.0.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
                      http://maven.apache.org/xsd/maven-4.0.0.xsd">
  ...
  <dependencies>
    <dependency>
      <groupId>org.apache.maven</groupId>
      <artifactId>maven-embedder</artifactId>
      <version>2.0</version>
      <exclusions>
        <exclusion>
          <groupId>org.apache.maven</groupId>
          <artifactId>maven-core</artifactId>
        </exclusion>
      </exclusions>
    </dependency>
    ...
  </dependencies>
  ...
</project>
```

Build
---
build元素可以分为两部分：BaseBuild（project级的build元素和profile定义的build元素）和 Build type。

### BaseBuild
BaseBuild包含了整个项目的一些基础信息，其结构一般如下：
```java
<build>
  <defaultGoal>install</defaultGoal>
  <directory>${basedir}/target</directory>
  <finalName>${artifactId}-${version}</finalName>
  <filters>
  <filter>filters/filter1.properties</filter>
  </filters>
  ...
</build>
```

#### resource
build还可以指定resourcesr的位置， resource一般不会被编译，但项目却需要这些resource，如代码生成。

#### Plugins
结构如下：
```java
<project>
  <build>
  ...
  <plugins>
    <plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-jar-plugin</artifactId>
    <version>2.0</version>
    <extensions>false</extensions>
    <inherited>true</inherited>
    <configuration>
    <classifier>test</classifier>
    </configuration>
    <dependencies>...</dependencies>
    <executions>...</executions>
    </plugin>
    </plugins>
  </build>
  </project>
```

除了需要groupId:artifactId:version标准信息，还有一些元素可以来配置plugins，如上述中的extensions，inherited等。

pluginManagement元素的配置和plugins的配置是一样的，不过pluginManagement的配置是用于集成，方便其在子POM中使用。

### The Build Element Set
Build type表示这些元素仅用于"project build"，尽管有多个元素，但实际上 project build 仅包括两组元素：directories, extensions。

#### Directories
directories可以为项目里各文件分别指定路径，如下：
```java
<project>
  <build>
    <sourceDirectory>${basedir}/src/main/java</sourceDirectory>
    <scriptSourceDirectory>${basedir}/src/main/scripts</scriptSourceDirectory>
    <testSourceDirectory>${basedir}/src/test/java</testSourceDirectory>
    <outputDirectory>${basedir}/target/classes</outputDirectory>
    <testOutputDirectory>${basedir}/target/test-classes</testOutputDirectory>
    ...
  </build>
  </project>
```
如果上述路径使用的是相对路径，则其根路径是`${basedir}`。

#### Extensions
extension是一系列在这个build中使用的其他artifacts。

Profiles
---

通过设置profiles, pom.xml可以根据不同的环境选择不同的配置。例如当项目根据运行的环境选择不同的数据库或不同的依赖。一个profile元素对应一个配置。如：

```java
<project>
...
  <profiles>
    <profile>
      <id>dev</id>
      <activation>
      <activeByDefault>false</activeByDefault> 
      <jdk>1.5</jdk> 
      <os>
      <name>Ubuntu</name> 
      <family>Linux</family>
      </os>
      <property>
      <name>customProperty</name>
      <value>BLUE</value>
      </property>
      <file>
      <exists>file1</exists> 
      <missing>file2</missing>
      </file>
      </activation>
      ...
    </profile>
  </profiles>
</project>

```
可以手动或自动的激活不同的profile。手动激活需要在输入mvn命令时使用`-P`指定profile，这里主要说下自动激活。可以在pom.xml中先定义好条件，当遇到这样的情况后，激活这个profile。有如下这些激活条件：

- activeByDefault  
  是否默认激活。
- jdk  
- os  
- property  
  如果属性customProperty被定义为BLUE则激活。  
- file  
  当file1存在时激活，当file2不存在时激活。  

Reference
---
- [POM Reference](http://maven.apache.org/pom.html)
- [Maven Assembly Plugin](http://maven.apache.org/plugins/maven-assembly-plugin/)
- [introduction to profiles](http://maven.apache.org/guides/introduction/introduction-to-profiles.html)
