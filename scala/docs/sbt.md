# SBT简介

_说明：本文是[Getting Started with sbt](http://www.scala-sbt.org/0.13/docs/Getting-Started.html)的简短笔记。_

## SBT命令说明
SBT build动作由`build.sbt`（任何以.sbt结尾的文件名也行）进行定义，build产生的文件默认放在`target`目录。

执行build操作时，有如下几种方式：

- sbt shell    
 在shell中执行sbt命令，进入sbt shell 进行build。
- batch mode   
 直接在shell中执行sbt相关命令，如`sbt clean compile "testOnly TestA TestB"`。由于该模式每次都需要JVM和JIT，所以build较慢。
- Continuous build and test   
 在sbt shell中，在命令前加`~`，会自动build修改的文件。如`~testQuick`。

sbt包含的命令如下：

  command  | 说明
--------|---------
clean   | 删除`target`目录所有生成的文件。
compile | 编译 `src/main/scala` 和 `src/main/java` 目录下的文件。
test    | 编译并运行所有test文件。
console | 启动一个包含所有编译的源文件和依赖的Scala编译器。使用`:quit`和Ctrl+D（UNIX）下退出sbt。
run \<argument\>* | 执行main方法。
package | 打jar包。
help \<command\> |  输出help等。
reload | 重新加载build定义文件。

## SBT语法说明
在使用sbt时，需先在project/build.properties文件中指定sbt版本号，如下：
```
sbt.version=0.13.013
```
如果本地没有指定的版本，sbt launcher将自动下载该版本。

sbt在检查项目和处理build文件时，会生成一个Project定义，在build.sbt中，可通过`lazy val root = (project in file("."))`这种方式创建。sbt Project由一系列sbt DSL构成，sbt DSL格式如下：
![setting-expression.png](../imgs/setting-expression.png)

由于key被定义为`SettingKey[String]`类型，`:=`被指定为String，所以value类型也需为String类型，否则定义将不会编译。

如下例子：
```
lazy val root = (project in file("."))
  .settings(
    name := "Hello",
    scalaVersion := "2.12.1"
  )
```

Key有如下三种类型：
- SettingKey[T]       
  value只计算一次。之后值不变。
- TaskKey[T]   
  每次需重新计算，key被称为task。
- InputKey[T]   
  命令行中的参数做为task key的输入。

### 添加lib依赖
若程序依赖第三方lib，有如下两种方法，其一是下载jars放在程序`lib/`目录下，其二是在sbt中添加依赖，语法为`libraryDependencies += groupID % artifactID % revision
`，如下添加10.4.1.3版本的Derby lib依赖：
```
val derby = "org.apache.derby" % "derby" % "10.4.1.3"

lazy val commonSettings = Seq(
  organization := "com.example",
  version := "0.1.0-SNAPSHOT",
  scalaVersion := "2.12.1"
)

lazy val root = (project in file("."))
  .settings(
    commonSettings,
    name := "Hello",
    libraryDependencies += derby
  )
```
`+=`将被加值加到原值上而非代替，`%`用于根据字符串构造Ivy模块ID。

当然，也可以使用`++=`一次性添加多个依赖：
```
libraryDependencies ++= Seq(
  groupID % artifactID % revision,
  groupID % otherID % otherRevision
)
```

#### 使用`%%`取得正确的scala版本
如果使用`libraryDependencies += "org.scala-tools" %% "scala-stm" % "0.3"`，groupID后跟`%%`，则sbt会将Scala征本添加到artifact后，如若scala版本为2.11.1，`libraryDependencies += "org.scala-tools" % "scala-stm_2.11.1" % "0.3"`使用`%%`的写法是`libraryDependencies += "org.scala-tools" %% "scala-stm" % "0.3"`。


### scope axes
根据上下文的不同，每个key可能会有不同的value，这种上下文称之为scope。scope有如下三种类型：

- Projects
- Configurations
- Tasks

#### Project Scope axe
若将多个项目放在同一个build定义中，每个项目都有属于自己的settings，Project scope可以被设置为全局scope。

#### Configurations Scope axe
一个configuration定义一种build，每种configuration可包含各自的classpath，源文件和生成的包。在sbt有如下configuration：
- Compile （定义`src/main/scala`配置）
- Test （定义`src/test/scala`配置）
- Runtime （定义run task的classpath）

#### Task Scope axe
Settings可以影响task的执行，为支持这种特性，一个task key可作为另一个key的scope。

#### Global scope
每种scope axe都可以被同类型的axe或Global scope axe代替，Global scope axe即将stting的值应用于该axe上的所有实例上。

### 插件
#### 声明插件
可通过将Ivy模块ID传递给`addSbtPlugin`的方式来创建插件，如`addSbtPlugin("com.typesafe.sbt" % "sbt-site" % "0.7.0")`，由于不是所有的插件都可以在默认仓库中找到，所以对于部分插件，需要先添加共仓库：`resolvers += Resolver.sonatypeRepo("public")`。

#### 启用和禁用插件
插件能声明自己的设置被自动添加到build定义中，如果使用一个需要显式开启的自动插件，可使用`enablePlugins()`方法显式开启，如：
```
lazy val util = (project in file("util")).
  enablePlugins(FooPlugin, BarPlugin).
  settings(
    name := "hello-util"
  )
```

#### 全局插件
若需要给所有项目安装插件，只需在`~/.sbt/<version>/plugins/`声明它们，为一性给所有项目添加插件，可创建`~/.sbt/0.13/plugins/build.sbt`并添加`addSbtPlugin()`表达式。由于这样会增加机器上的依赖，所以这个特性就少用。

## build风格
sbt build有如下几种风格：

- 多项目.sbt build 定义
- bare .sbt build 定义
- .scala build 定义

以下分别叙述。

### 多项目.sbt build 定义
将多个相关项目定义在一个build文件的一个优点是若项目间有依赖关系，可方便修改。对于通用的设置，也可统一设置，如下：
```
lazy val commonSettings = Seq(
  organization := "com.example",
  version := "0.1.0",
  scalaVersion := "2.12.1"
)

lazy val core = (project in file("core")).
  settings(commonSettings: _*).
  settings(
    // other settings
  )

lazy val util = (project in file("util")).
  settings(commonSettings: _*).
  settings(
    // other settings
  )
```
传入序列给参数文野时需要调用`_*`。若项目之间有依赖，可通过`dependsOn()`方法来实现。

### bare .sbt  build 定义
bare sbt根据.sbt的位置隐匿定义一个项目，bare sbt build 定义由一个`Setting[_]`表达式的列表组成，而不是定义Project，如下：
```
name := "hello"

version := "1.0"

scalaVersion := "2.12.1"
```
注意，在sbt-0.13.7之前，行之间必须以空行分隔。

### .scala build 定义
在老版本的sbt中，.scala是创建多项目build定义的唯一方式，在sbt-0.13后添加的多项目.sbt生成定义，用来代替.scala build这种方式。具体见[附录：.scala 构建定义](http://www.scala-sbt.org/0.13/docs/zh-cn/Full-Def.html)，这里暂不总结。



