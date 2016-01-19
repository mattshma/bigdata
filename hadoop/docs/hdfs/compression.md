压缩
===
从效率和可分块的角度来看，选择lzo做为压缩方式。

准备
===
在正式安装hadoop-lzo前，还需要安装如下软件。

### lzo
在[lzo](http://www.oberhumer.com/opensource/lzo/download/)中下载并解压安装：

```
# ./configure --enable-shared --prefix /usr/local/lzo-2.09
# make && make install
```

### lzop
下载[lzop](http://www.lzop.org/)，解压：

```
# tar xvzf lzop-1.03.tar.gz
# cd lzop-1.03
# export C_INCLUDE_PATH=/usr/local/lzo-2.09/include
# export LIBRARY_PATH=/usr/local/lzo-2.09/lib
# make; make install
```
可以测试下该lzop。

### maven
注意java版本与maven版本之前的兼容性，maven3.3版本以上需要java1.7。maven下载并解压后，设置`MAVEN_HOME`和`PATH`：
```
# vim /etc/profile
export MAVEN_HOME=/usr/local/maven
export PATH=$PATH:$MAVEN_HOME/bin
```

安装hadoop-lzo
===

- 下载`git clone https://github.com/twitter/hadoop-lzo/`。
- 修改pom.xml文件：
因为使用的Hadoop版本为2.3.0，因此修改如下地方
```
<properties>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <hadoop.current.version>2.4.0</hadoop.current.version>
    <hadoop.old.version>1.0.4</hadoop.old.version>
</properties>
```
为
```
<properties>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <hadoop.current.version>2.3.0</hadoop.current.version>
    <hadoop.old.version>1.0.4</hadoop.old.version>
  </properties>
```
- 生成jar包，如下：
```
# export C_INCLUDE_PATH=/usr/local/lzo-2.09/include
# export LIBRARY_PATH=/usr/local/lzo-2.09/lib
# mvn clean package -Dmaven.test.skip=true`
```

- 将生成的jar拷贝到hadoop的lib目录。
- 修改配置文件core-site.xml:
```
<property>
    <name>io.compression.codecs</name>
    <value>org.apache.hadoop.io.compress.DefaultCodec,org.apache.hadoop.io.compress.GzipCodec,org.apache.hadoop.io.compress.BZip2Codec,org.apache.hadoop.io.compress.DeflateCodec,org.apache.hadoop.io.compress.SnappyCodec,org.apache.hadoop.io.compress.Lz4Codec,com.hadoop.compression.lzo.LzoCodec,com.hadoop.compression.lzo.LzopCodec</value>
  </property>
  <property>
      <name>io.compression.codec.lzo.class</name>
      <value>com.hadoop.compression.lzo.LzoCodec</value>
  </property>
```
- 若希望mapreduce的中间也被压缩，修改配置文件mapred-site.xml:
```
<property>
  <name>mapreduce.map.output.compress</name>
  <value>true</value>
</property>
<property>
  <name>mapred.map.output.compress.codec</name>
  <value>org.apache.hadoop.io.compress.LzoCodec</value>
</property>
<property>
     <name>mapred.child.env</name>
     <value>LD_LIBRARY_PATH=/opt/cloudera/parcels/CDH/lib/hadoop/</value>
</property>
```

> LzoCodec与LzopCodec的比较
> LzoCodec 与 LzopCodec的区别如同Lzo与Lzop的区别，前者是一种快速的压缩库，后者在前者的基础上添加了额外的文件头。
> 
> 若使用LzoCodec作为Reduce输出，则输出文件的扩展名为`.lzo_deflate`，其无法作为MapReduce的的输入，`DistributedLzoIndexer`也无法为其创建索引；若使用LzopCodec作为Reduce输出，则输出文件的扩展名为 `.lzo`。所以一般而言，map输出的中间结果使用LzoCodec，而reduce输出使用LzopCodec。可参考[What's the difference between the LzoCodec and the LzopCodec in Hadoop-LZO?](https://www.quora.com/Whats-the-difference-between-the-LzoCodec-and-the-LzopCodec-in-Hadoop-LZO)。
>


生成lzo索引文件
===
lzop压缩文件然后上传到hdfs，执行如下命令可在本地压缩：

```
hadoop jar /path/to/your/hadoop-lzo.jar com.hadoop.compression.lzo.LzoIndexer big_file.lzo
```

若希望通过mapreduce来进行压缩，命令如下：
```
hadoop jar /path/to/your/hadoop-lzo.jar com.hadoop.compression.lzo.DistributedLzoIndexer big_file.lzo
```

报错
===
当运行压缩时，报错如下：
```
16/01/18 18:36:45 INFO lzo.GPLNativeCodeLoader: Loaded native gpl library from the embedded binaries
16/01/18 18:36:45 WARN lzo.LzoCompressor: java.lang.UnsatisfiedLinkError: Cannot load liblzo2.so.2 (liblzo2.so.2: cannot open shared object file: No such file or directory)!
16/01/18 18:36:45 ERROR lzo.LzoCodec: Failed to load/initialize native-lzo library
```
在hadoop-env.sh文件中，配置安装lzo的路径即可：

```
export LD_LIBRARY_PATH=/usr/local/lzo-2.09/lib
```

MapReduce压缩文件
===
若在HDFS中已经存在的文件，要通过本地lzop压缩的话，还需要先下载文件，再压缩，再上传，显然低效烦琐，可以通过读取文件然后在Reduce阶段进行压缩。[todo]

Reference
===
- [Choosing a Data Compression Format](http://www.cloudera.com/content/www/en-us/documentation/enterprise/5-2-x/topics/admin_data_compression_performance.html)
- [Data Compression in Hadoop](http://comphadoop.weebly.com/)
- [Snappy and Hadoop](http://blog.cloudera.com/blog/2011/09/snappy-and-hadoop/)
- [Is Snappy splittable or not splittable](http://stackoverflow.com/questions/32382352/is-snappy-splittable-or-not-splittable)
- [LZO vs Snappy vs LZF vs ZLIB, A comparison of compression algorithms for fat cells in HBase](http://blog.erdemagaoglu.com/post/4605524309/lzo-vs-snappy-vs-lzf-vs-zlib-a-comparison-of)
