Maven
===

这里记录下在 使用Maven时的一些知识点。

Installation
---
  在[Apache Maven Project](http://maven.apache.org/download.cgi)中下载maven，解压并按照`README.txt`配置。运行`mvn -v`查看是否配置成功。

Configuring Maven
---
  根据`setting.xml`知，有两种级别的配置: User Level 和 Global Level。`localRepository`默认为` ${user.home}/.m2/repository/`。

Creating a project
---
  这里以"hello world"程序为例，说下创建maven应用的大致步骤。参考官方文档，运行命令如下：  
- `mvn archetype:generate -DgroupId=com.mycompany.app -DartifactId=my-app -DinteractiveMode=false`。  
  `archetype`是Maven的一个模板工具包，帮助我们快速创建一个Maven工程的主干。`mvn -D`定义系统属性，如`-DartifactId`定义了应用的名称，`-DinteractiveMode=false`的意思是指令执行过程中选择默认选项，这些参数将传递给archetype中的goals。生成的`pom.xml`是maven的核心配置文件。

- `mvn package`  
  package是[build lifecycle](http://maven.apache.org/guides/introduction/introduction-to-the-lifecycle.html)中的一步。这条命令将lifecycle从头一直执行到package这一步。这步可以看到生成的jar包。

- `java -cp target/my-app-1.0-SNAPSHOT.jar com.mycompany.app.App`  
  检查生成的jar包，这条命令的结果是`Hello World!`

Lifecycle、Phase && Goal
---
这里说下上面这些命令的运行机制。mvn命令是`mvn [options] [<goal(s)>] [<phase(s)>]`这样的。其中`option`这部分可以使用`mvn -h`查看，这里说下goal和phase.

### lifecycle
Maven是基于构建的生命周期(a build lifecycle)这个概念的，完成Maven工程对应着完成相应的生命周期。有三个内置的生命周期: default, clean 和 site.default生命周期处理工程的发布，clean生命周期处理工程的清理，而site生命周期处理创建工程的site文档。

### phases
lifecycle是由一系列不同的phases组成的。如default生命周期有以下这些phases：

- validate
- compile
- test
- package - 将compiled code打成指定格式包，如JAR
- integration-test
- verify
- install - 安装package到本地repository
- deploy

执行完default的生命周期意味着执行了以上所有的phases。如果选择执行到某个phase，该phase之前的所有phases都将被执行。

### goals
然而，即使phase对lifecycle中每个指定的步骤负责，但完成这个步骤的方法仍然很多，所以指定"plugin goals"来约束这些phases."plugin goal"代表了一个指定的任务，这个任务负责创建和管理一个工程。

调用goals和phases的顺序决定了build liftcycle的执行顺序。以`mvn clean dependency:copy-dependencies package`为例，如果这个命令被执行，意味着"clean phase"被执行（这会执行clean lifecycle中在clean之前的所有phases，包括clean phase本身），接着执行"dependency:copy-dependencies goal"，最后执行"package phase"（同样的，default lifecycle中package之前包括package phases都将被执行。）

一个build phase可以有0个或者多个goals来约束它。如果一个build phase没有一个goals来约束它，这个build phase将不会被执行。如果有多个goals约束它，这些goals都会被执行。

### 使用build lifecycle建立工程
当初初始化一个Maven工程时，怎样给这些phases指定goals呢？

#### packaging
第一种方法是为pom.xml中<packaging>元素设置packaging值。默认packaging 值是jar。每个packaging都包含一系列goals绑定到特定的phase。这也是为什么上述build phase没有指定goals却还能执行的原因。

#### plugins
第二种方法是给phases添加goals。Plugins是能给Maven提供goals的工件(artifacts)，plugins包含了lifecycle pahse绑定哪些goals的信息。如果多个goals约束着一个特定的phase，那么将会优先执行"packaing"中的goals，接着是POM中的这些定义。可以使用<executions>更大程度的控制这些goals的执行顺序。

以下是一个例子：
```
...
 <plugin>
   <groupId>org.codehaus.modello</groupId>
   <artifactId>modello-maven-plugin</artifactId>
   <version>1.4</version>
   <executions>
     <execution>
       <configuration>
         <models>
           <model>src/main/mdo/maven.mdo</model>
         </models>
         <version>4.0.0</version>
       </configuration>
       <goals>
         <goal>java</goal>
       </goals>
     </execution>
   </executions>
 </plugin>
...
```

Others
---
- 删除一个project  
  在project目录上，运行`mvn clean packege`即可删除一个project。


Reference List
---
- [Maven in 5 Minutes](http://maven.apache.org/guides/getting-started/maven-in-five-minutes.html)
- [Available Plugins](http://maven.apache.org/plugins/index.html)
- [Introduction to the Build Lifecycle](http://maven.apache.org/guides/introduction/introduction-to-the-lifecycle.html)
