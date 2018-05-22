# Maven 生成可直接运行的 Jar 包

## 使用 maven-jar-plugin 和 maven-dependency-plugin 插件打包
定义一个执行的 JAR 文件，一般需要采取如下步骤：
- 在定义可执行的 JAR 的 MANIFEST.MF 文件中定义一个 main 类。
- 找到项目依赖的所有库。
- 在 MANIFEST.MF 文件中包含那些库，便于应用程序找到它们。

如下：
```
<build>  
    <plugins>  
        <plugin>  
            <groupId>org.apache.maven.plugins</groupId>  
            <artifactId>maven-jar-plugin</artifactId>  
            <version>3.1.0</version>  
            <configuration>  
                <archive>  
                    <manifest>  
                        <addClasspath>true</addClasspath>  
                        <classpathPrefix>lib/</classpathPrefix>  
                        <mainClass>com.mypackage.MyClass</mainClass>  
                    </manifest>  
                </archive>  
            </configuration>  
        </plugin>  
        <plugin>  
            <groupId>org.apache.maven.plugins</groupId>  
            <artifactId>maven-dependency-plugin</artifactId>  
            <version>3.1.0</version>  
            <executions>  
                <execution>  
                    <id>copy-dependencies</id>  
                    <phase>package</phase>  
                    <goals>  
                        <goal>copy-dependencies</goal>  
                    </goals>  
                    <configuration>  
                        <outputDirectory>${project.build.directory}/lib</outputDirectory>  
                    </configuration>  
                </execution>  
            </executions>  
        </plugin>
    </plugins>  
</build>  
```

Maven 插件通过一个 `<configuration>` 元素公布其配置，maven-jar-plugin 修改它的 archive 属性，特别是 manifest 属性，其控制 MANIFEST.MF 文件的内容，其包含 3 个元素：
- addClassPath      
  该元素设置为 true，即 maven-jar-plugin 添加一个 `Class-Path` 元素到 MANIFEST.MF 文件，以及在 `Class-Path` 元素中包括所有依赖项。
- classpathPrefix    
  所有 `Class-Path` 的前缀路径，默认为`""`。
- mainClass   
  主要入口。

更多参数见[官网](http://maven.apache.org/shared/maven-archiver/index.html)。

仅通过 maven-jar-plugin 定义可直接执行 JAR 包的元信息不够，还需通过 maven-dependency-plugin 将依赖包拷贝到指定位置。参照[示例](https://maven.apache.org/plugins/maven-dependency-plugin/examples/copying-project-dependencies.html)，设置依赖包的拷贝路径。

这种方式生成 JAR 包不包括依赖，在运行时，需要指定 `outputDirectory` 中包的位置。以下方式会将依赖包也打到可运行 JAR 包中。 

## maven-assembly-plugin 

如下：
```
<build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-assembly-plugin</artifactId>
                <version>3.1.0</version>
                <configuration>
                    <archive>
                        <manifest>
                            <mainClass>com.xxx.Main</mainClass>
                        </manifest>
                    </archive>
                    <descriptorRefs>
                        <descriptorRef>jar-with-dependencies</descriptorRef>
                    </descriptorRefs>
                </configuration>
                <executions>
                    <execution>
                        <id>make-assembly</id>
                        <phase>package</phase>
                        <goals>
                            <goal>single</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>
```
执行打包后，会生成 xx-jar-with-dependencies.jar 文件，该文件包括了所有依赖的 JAR 包，可直接通过 `java -jar` 运行。预定义格式 jar-with-dependencies 实际上只有基本的 Uber-Jar 打包功能，背后集成是maven-shade-plugin。

## maven-shade-plugin

如下：
```
<build>
    <plugins>
        <plugin>
            <artifactId>maven-shade-plugin</artifactId>
            <version>3.1.0</version>
            <executions>
                <execution>
                    <phase>package</phase>
                    <goals>
                        <goal>shade</goal>
                    </goals>
                    <configuration>
                        <transformers>
                            <transformer implementation="org.apache.maven.plugins.shade.resource.ManifestResourceTransformer">
                                <manifestEntries>
                                    <mainClass>com.xxx.Main</mainClass>
                                </manifestEntries>
                            </transformer>
                        </transformers>
                    </configuration>
                </execution>
            </executions>
        </plugin>
    </plugins>
</build>
```

maven-shade-plugin 功能很强大，应用场景也较多：排除一些包；更改强依赖包的包名（如：业务方依赖A.B.C包，可将其变更为 A.B1.C 包，较常用于多方引用不同版本的某一依赖）。

## 参考
- [Guide to Configuring Plug-ins](https://maven.apache.org/guides/mini/guide-configuring-plugins.html)
- [Apache Maven Archiver](https://maven.apache.org/shared/maven-archiver/index.html#manifest)
- [Apache Maven Dependency Plugin](https://maven.apache.org/plugins/maven-dependency-plugin/)
- [dependency:copy-dependencies](https://maven.apache.org/plugins/maven-dependency-plugin/copy-dependencies-mojo.html)
- [Apache Maven Assembly Plugin](http://maven.apache.org/plugins/maven-assembly-plugin/)
- [Apache Maven Shade Plugin](http://maven.apache.org/plugins/maven-shade-plugin/)
- [用 Maven 管理项目文件周期的技巧](https://www.ibm.com/developerworks/cn/java/j-5things13/index.html)
