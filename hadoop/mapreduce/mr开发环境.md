# MR开发环境

以下环境均基于 IntelliJ。
## 本地开发
本地开发环境不需要安装任何 hadoop 组件，只依赖于 maven 配置。如下是整个过程：
### Inteliij 中新建 maven 项目。   
  填写 groupId 和 artifactId 后，生成的 pom.xml 文件中加入 hadoop 相关依赖，如下：
```
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>org.mytest</groupId>
    <artifactId>wordcount</artifactId>
    <version>1.0-SNAPSHOT</version>

    <properties>
        <hadoop.version>2.6.0-cdh5.7.1</hadoop.version>
    </properties>

    <repositories>
        <repository>
            <id>cloudera</id>
            <url>https://repository.cloudera.com/artifactory/cloudera-repos/</url>
        </repository>
    </repositories>

    <dependencies>
        <dependency>
            <groupId>org.apache.hadoop</groupId>
            <artifactId>hadoop-client</artifactId>
            <version>${hadoop.version}</version>
        </dependency>

        <dependency>
            <groupId>org.apache.hadoop</groupId>
            <artifactId>hadoop-common</artifactId>
            <version>${hadoop.version}</version>
        </dependency>
    </dependencies>
</project>
```
### 新建 WordCount 文件   
  src/main/java 目录下，新建 package：org.mytest，新建文件 WordCount.java，内容如下：
```
package org.mytest;

import java.io.IOException;
import java.util.StringTokenizer;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;

public class WordCount {

    public static class TokenizerMapper extends Mapper<Object, Text, Text, IntWritable> {
        private final static IntWritable one = new IntWritable(1);
        private Text word = new Text();

        public void map(Object key, Text value, Context context
        ) throws IOException, InterruptedException {
            StringTokenizer itr = new StringTokenizer(value.toString());
            while (itr.hasMoreTokens()) {
                word.set(itr.nextToken());
                context.write(word, one);
            }
        }
    }

    public static class IntSumReducer extends Reducer<Text, IntWritable, Text, IntWritable> {
        private IntWritable result = new IntWritable();

        public void reduce(Text key, Iterable<IntWritable> values,
                           Context context
        ) throws IOException, InterruptedException {
            int sum = 0;
            for (IntWritable val : values) {
                sum += val.get();
            }
            result.set(sum);
            context.write(key, result);
        }
    }

    public static void main(String[] args) throws Exception {
        Configuration conf = new Configuration();
        Job job = Job.getInstance(conf, "word count");
        job.setJarByClass(WordCount.class);
        job.setMapperClass(TokenizerMapper.class);
        job.setCombinerClass(IntSumReducer.class);
        job.setReducerClass(IntSumReducer.class);
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(IntWritable.class);
        FileInputFormat.addInputPath(job, new Path(args[0]));
        FileOutputFormat.setOutputPath(job, new Path(args[1]));
        System.exit(job.waitForCompletion(true) ? 0 : 1);
    }
}
```

### 配置 Run Configuration    
点击 Run --> Edit Configurations --> + --> Application，填入值为：
- Name: wordcount
- Main Class: org.mytest.WordCount
- Program arguments: input/ output/
- Use classpath of module: wordcount

或者点击 `main` 方法左边的绿色小三角执行代码，然后修改其配置如上述配置。

### 创建输入目录 input 并执行程序
在 src 同级目录（即项目根目录）下创建目录 input，然后创建一个或者几个文件做为输入文件。然后运行代码，可以看到，运行完成后，在项目根目录下会生成 output 目录，点击 part-r-00000 即可看到结果。若需要再次运行该代码，需先删除 output。

## 上传 Jar 包执行
若需要上传 jar 包到 Hadoop 环境中执行，在开发好程序后，无须在配置 Run Configuration 和 input 等，直接运行 `maven package` 打包。将生成的 target/wordcount-1.0-SNAPSHOT.jar 上传到 Hadoop 机器上，执行如下命令：
```
// 创建 input 目录
$ hdfs dfs -mkdir /user/ma/input
// 上传 wordcount 文本
$ hdfs dfs -put wordcount.txt /user/ma/input
// 执行 wordcount，格式为 hadoop jar JAR_Name Class_Name input output 
$ hadoop jar wordcount-1.0-SNAPSHOT.jar com.ctrip.WordCount /user/ma/input /user/ma/output
// 查看运行结果
$ hdfs dfs -cat /user/admin/maming/pg/output/part-r-00000
```

当然以上过程需要该 hadoop 机器的默认配置都是正确的。如果默认不对，可通过 `--conf` 指定配置路径；或者在 maven 打包前，将 core-site.xml, hdfs-site.xml, mapred-site.xml, yarn-site.xml 拷贝到 resources 目录，这样打包时会将 resources 下的文件添加到 classpath 下。

## 本地开发，远程调试

将 core-site.xml, hdfs-site.xml, mapred-site.xml, yarn-site.xml 拷贝到 resources 目录下，设置 Run Configuration 中 Program arguments 为 hdfs 上文件路径，如 `hdfs://nameservice/user/ma/wordcount/input hdfs://nameservice/user/ma/wordcount/outpu`，然后执行即可。
