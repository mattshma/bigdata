# Flume配置

在安装完Flume后，还需要做如下配置。

## 检查/etc/hosts
若flume与kafka和hdfs，hbase等有交集，需将相应服务的信息配置到`/etc/hosts`文件中。

## 修改flume-env.sh
指定`JAVA_HOME`和`JAVA_OPTS`。

## 拷贝jar包
若直接使用flume，可能会报如下错误。

###  EventTimestampInterceptor
报错如下：
```
2016-04-12 11:21:46,564 (conf-file-poller-0) [ERROR - org.apache.flume.channel.ChannelProcessor.configureInterceptors(ChannelProcessor.java:113)] Builder class not found. Exception follows.
java.lang.ClassNotFoundException: org.apache.flume.interceptor.EventTimestampInterceptor$Builder
        at java.net.URLClassLoader.findClass(URLClassLoader.java:381)
        at java.lang.ClassLoader.loadClass(ClassLoader.java:424)
        at sun.misc.Launcher$AppClassLoader.loadClass(Launcher.java:331)
        at java.lang.ClassLoader.loadClass(ClassLoader.java:357)
        at java.lang.Class.forName0(Native Method)
        at java.lang.Class.forName(Class.java:264)
        at org.apache.flume.interceptor.InterceptorBuilderFactory.newInstance(InterceptorBuilderFactory.java:48)
        at org.apache.flume.channel.ChannelProcessor.configureInterceptors(ChannelProcessor.java:109)
        at org.apache.flume.channel.ChannelProcessor.configure(ChannelProcessor.java:80)
        at org.apache.flume.conf.Configurables.configure(Configurables.java:41)
        at org.apache.flume.node.AbstractConfigurationProvider.loadSources(AbstractConfigurationProvider.java:348)
        at org.apache.flume.node.AbstractConfigurationProvider.getConfiguration(AbstractConfigurationProvider.java:97)
        at org.apache.flume.node.PollingPropertiesFileConfigurationProvider$FileWatcherRunnable.run(PollingPropertiesFileConfigurationProvider.java:140)
        at java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:511)
        at java.util.concurrent.FutureTask.runAndReset(FutureTask.java:308)
        at java.util.concurrent.ScheduledThreadPoolExecutor$ScheduledFutureTask.access$301(ScheduledThreadPoolExecutor.java:180)
        at java.util.concurrent.ScheduledThreadPoolExecutor$ScheduledFutureTask.run(ScheduledThreadPoolExecutor.java:294)
        at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1142)
        at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:617)
        at java.lang.Thread.run(Thread.java:745)
2016-04-12 11:21:46,567 (conf-file-poller-0) [ERROR - org.apache.flume.node.AbstractConfigurationProvider.loadSources(AbstractConfigurationProvider.java:361)] Source s1 has been removed due to an error during configuration
org.apache.flume.FlumeException: Interceptor.Builder not found.
```

下载[flume-timestamp-interceptor](https://github.com/haebin/flume-timestamp-interceptor)，将flume-timestamp-interceptor-1.2.0.jar放到FLUME_HOME/lib中。

### hdfs
报错如下：
```
2016-06-24 15:38:13,116 (SinkRunner-PollingRunner-DefaultSinkProcessor) [WARN - org.apache.flume.sink.hdfs.HDFSEventSink.process(HDFSEventSink.java:455)] HDFS IO error
java.io.IOException: No FileSystem for scheme: hdfs
	at org.apache.hadoop.fs.FileSystem.getFileSystemClass(FileSystem.java:2623)
	at org.apache.hadoop.fs.FileSystem.createFileSystem(FileSystem.java:2637)
	at org.apache.hadoop.fs.FileSystem.access$200(FileSystem.java:93)
	at org.apache.hadoop.fs.FileSystem$Cache.getInternal(FileSystem.java:2680)
	at org.apache.hadoop.fs.FileSystem$Cache.get(FileSystem.java:2662)
	at org.apache.hadoop.fs.FileSystem.get(FileSystem.java:379)
	at org.apache.hadoop.fs.Path.getFileSystem(Path.java:296)
	at org.apache.flume.sink.hdfs.BucketWriter$1.call(BucketWriter.java:243)
	at org.apache.flume.sink.hdfs.BucketWriter$1.call(BucketWriter.java:235)
	at org.apache.flume.sink.hdfs.BucketWriter$9$1.run(BucketWriter.java:679)
	at org.apache.flume.auth.SimpleAuthenticator.execute(SimpleAuthenticator.java:50)
	at org.apache.flume.sink.hdfs.BucketWriter$9.call(BucketWriter.java:676)
	at java.util.concurrent.FutureTask$Sync.innerRun(FutureTask.java:334)
	at java.util.concurrent.FutureTask.run(FutureTask.java:166)
	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1110)
	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:603)
	at java.lang.Thread.run(Thread.java:722)
```
将hadoop-hdfs-2.6.0-cdh5.6.0.jar放入FLUME_HOME/lib中。

### SequenceFile
报错如下：
```
2016-04-12 12:01:02,769 (conf-file-poller-0) [ERROR - org.apache.flume.node.PollingPropertiesFileConfigurationProvider$FileWatcherRunnable.run(PollingPropertiesFileConfigurationProvider.java:145)] Failed to start agent because dependencies were not found in classpath. Error follows.
java.lang.NoClassDefFoundError: org/apache/hadoop/io/SequenceFile$CompressionType
        at org.apache.flume.sink.hdfs.HDFSEventSink.configure(HDFSEventSink.java:239)
        at org.apache.flume.conf.Configurables.configure(Configurables.java:41)
        at org.apache.flume.node.AbstractConfigurationProvider.loadSinks(AbstractConfigurationProvider.java:413)
        at org.apache.flume.node.AbstractConfigurationProvider.getConfiguration(AbstractConfigurationProvider.java:98)
        at org.apache.flume.node.PollingPropertiesFileConfigurationProvider$FileWatcherRunnable.run(PollingPropertiesFileConfigurationProvider.java:140)
        at java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:511)
        at java.util.concurrent.FutureTask.runAndReset(FutureTask.java:308)
        at java.util.concurrent.ScheduledThreadPoolExecutor$ScheduledFutureTask.access$301(ScheduledThreadPoolExecutor.java:180)
        at java.util.concurrent.ScheduledThreadPoolExecutor$ScheduledFutureTask.run(ScheduledThreadPoolExecutor.java:294)
        at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1142)
        at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:617)
        at java.lang.Thread.run(Thread.java:745)
Caused by: java.lang.ClassNotFoundException: org.apache.hadoop.io.SequenceFile$CompressionType
        at java.net.URLClassLoader.findClass(URLClassLoader.java:381)
        at java.lang.ClassLoader.loadClass(ClassLoader.java:424)
        at sun.misc.Launcher$AppClassLoader.loadClass(Launcher.java:331)
        at java.lang.ClassLoader.loadClass(ClassLoader.java:357)
        ... 12 more
```
将hadoop-common-2.6.0-cdh5.6.0.jar和commons-configuration-1.7.jar放入FLUME_HOME/lib中。

### zookeeper/Watcher
报错：
```
java.lang.NoClassDefFoundError: org/apache/zookeeper/Watcher
        at java.lang.ClassLoader.defineClass1(Native Method)
        at java.lang.ClassLoader.defineClass(ClassLoader.java:763)
        at java.security.SecureClassLoader.defineClass(SecureClassLoader.java:142)
        at java.net.URLClassLoader.defineClass(URLClassLoader.java:467)
        at java.net.URLClassLoader.access$100(URLClassLoader.java:73)
        at java.net.URLClassLoader$1.run(URLClassLoader.java:368)
        at java.net.URLClassLoader$1.run(URLClassLoader.java:362)
        at java.security.AccessController.doPrivileged(Native Method)
        at java.net.URLClassLoader.findClass(URLClassLoader.java:361)
        at java.lang.ClassLoader.loadClass(ClassLoader.java:424)
        at sun.misc.Launcher$AppClassLoader.loadClass(Launcher.java:331)
        at java.lang.ClassLoader.loadClass(ClassLoader.java:357)
        at kafka.consumer.ZookeeperConsumerConnector.connectZk(ZookeeperConsumerConnector.scala:156)
        at kafka.consumer.ZookeeperConsumerConnector.<init>(ZookeeperConsumerConnector.scala:114)
        at kafka.javaapi.consumer.ZookeeperConsumerConnector.<init>(ZookeeperConsumerConnector.scala:65)
        at kafka.javaapi.consumer.ZookeeperConsumerConnector.<init>(ZookeeperConsumerConnector.scala:67)
        at kafka.consumer.Consumer$.createJavaConsumerConnector(ConsumerConnector.scala:100)
        at kafka.consumer.Consumer.createJavaConsumerConnector(ConsumerConnector.scala)
        at org.apache.flume.source.kafka.KafkaSourceUtil.getConsumer(KafkaSourceUtil.java:47)
        at org.apache.flume.source.kafka.KafkaSource.start(KafkaSource.java:200)
        at org.apache.flume.source.PollableSourceRunner.start(PollableSourceRunner.java:74)
        at org.apache.flume.lifecycle.LifecycleSupervisor$MonitorRunnable.run(LifecycleSupervisor.java:251)
        at java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:511)
        at java.util.concurrent.FutureTask.runAndReset(FutureTask.java:308)
        at java.util.concurrent.ScheduledThreadPoolExecutor$ScheduledFutureTask.access$301(ScheduledThreadPoolExecutor.java:180)
        at java.util.concurrent.ScheduledThreadPoolExecutor$ScheduledFutureTask.run(ScheduledThreadPoolExecutor.java:294)
        at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1142)
        at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:617)
        at java.lang.Thread.run(Thread.java:745)
Caused by: java.lang.ClassNotFoundException: org.apache.zookeeper.Watcher
        at java.net.URLClassLoader.findClass(URLClassLoader.java:381)
        at java.lang.ClassLoader.loadClass(ClassLoader.java:424)

```
将zookeeper-3.4.5-cdh5.6.0.jar拷贝到FLUME_HOME/lib中。

### PlatformName
报错：
```
java.lang.NoClassDefFoundError: org/apache/hadoop/util/PlatformName
        at org.apache.hadoop.security.UserGroupInformation.getOSLoginModuleName(UserGroupInformation.java:365)
        at org.apache.hadoop.security.UserGroupInformation.<clinit>(UserGroupInformation.java:410)
        at org.apache.hadoop.fs.FileSystem$Cache$Key.<init>(FileSystem.java:2806)
        at org.apache.hadoop.fs.FileSystem$Cache$Key.<init>(FileSystem.java:2798)
        at org.apache.hadoop.fs.FileSystem$Cache.get(FileSystem.java:2661)
        at org.apache.hadoop.fs.FileSystem.get(FileSystem.java:379)
        at org.apache.hadoop.fs.Path.getFileSystem(Path.java:296)
        at org.apache.flume.sink.hdfs.BucketWriter$1.call(BucketWriter.java:243)
        at org.apache.flume.sink.hdfs.BucketWriter$1.call(BucketWriter.java:235)
        at org.apache.flume.sink.hdfs.BucketWriter$9$1.run(BucketWriter.java:679)
        at org.apache.flume.auth.SimpleAuthenticator.execute(SimpleAuthenticator.java:50)
        at org.apache.flume.sink.hdfs.BucketWriter$9.call(BucketWriter.java:676)
        at java.util.concurrent.FutureTask.run(FutureTask.java:266)
        at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1142)
        at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:617)
        at java.lang.Thread.run(Thread.java:745)
Caused by: java.lang.ClassNotFoundException: org.apache.hadoop.util.PlatformName
        at java.net.URLClassLoader.findClass(URLClassLoader.java:381)
        at java.lang.ClassLoader.loadClass(ClassLoader.java:424)
        at sun.misc.Launcher$AppClassLoader.loadClass(Launcher.java:331)
        at java.lang.ClassLoader.loadClass(ClassLoader.java:357)
        ... 16 more
```


拷贝hadoop-auth-2.6.0-cdh5.6.0.jar到FLUME_HOME/lib中。

### Tracer
报错如下：
```
2016-04-12 16:40:51,642 (SinkRunner-PollingRunner-DefaultSinkProcessor) [ERROR - org.apache.flume.sink.hdfs.HDFSEventSink.process(HDFSEventSink.java:459)] process failed
java.lang.NoClassDefFoundError: org/apache/htrace/core/Tracer$Builder
    at org.apache.hadoop.fs.FsTracer.get(FsTracer.java:42)
    at org.apache.hadoop.fs.FileSystem.createFileSystem(FileSystem.java:2630)
    at org.apache.hadoop.fs.FileSystem.access$200(FileSystem.java:93)
    at org.apache.hadoop.fs.FileSystem$Cache.getInternal(FileSystem.java:2680)
    at org.apache.hadoop.fs.FileSystem$Cache.get(FileSystem.java:2662)
    at org.apache.hadoop.fs.FileSystem.get(FileSystem.java:379)
    at org.apache.hadoop.fs.Path.getFileSystem(Path.java:296)
    at org.apache.flume.sink.hdfs.BucketWriter$1.call(BucketWriter.java:243)
    at org.apache.flume.sink.hdfs.BucketWriter$1.call(BucketWriter.java:235)
    at org.apache.flume.sink.hdfs.BucketWriter$9$1.run(BucketWriter.java:679)
    at org.apache.flume.auth.SimpleAuthenticator.execute(SimpleAuthenticator.java:50)
    at org.apache.flume.sink.hdfs.BucketWriter$9.call(BucketWriter.java:676)
    at java.util.concurrent.FutureTask.run(FutureTask.java:266)
    at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1142)
    at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:617)
    at java.lang.Thread.run(Thread.java:745)
Caused by: java.lang.ClassNotFoundException: org.apache.htrace.core.Tracer$Builder
    at java.net.URLClassLoader.findClass(URLClassLoader.java:381)
    at java.lang.ClassLoader.loadClass(ClassLoader.java:424)
    at sun.misc.Launcher$AppClassLoader.loadClass(Launcher.java:331)
    at java.lang.ClassLoader.loadClass(ClassLoader.java:357)
    ... 16 more
```
拷贝htrace-core4-4.0.1-incubating.jar到FLUME_HOME/lib中。

### hadoop config files
HDFS开启HA，设置了nameservice，故flume无法找到hdfs地址，报错如下：
```
java.lang.IllegalArgumentException: java.net.UnknownHostException: nameservice1
	at org.apache.hadoop.security.SecurityUtil.buildTokenService(SecurityUtil.java:374)
	at org.apache.hadoop.hdfs.NameNodeProxies.createNonHAProxy(NameNodeProxies.java:310)
	at org.apache.hadoop.hdfs.NameNodeProxies.createProxy(NameNodeProxies.java:176)
	at org.apache.hadoop.hdfs.DFSClient.<init>(DFSClient.java:708)
	at org.apache.hadoop.hdfs.DFSClient.<init>(DFSClient.java:651)
	at org.apache.hadoop.hdfs.DistributedFileSystem.initialize(DistributedFileSystem.java:148)
	at org.apache.hadoop.fs.FileSystem.createFileSystem(FileSystem.java:2643)
	at org.apache.hadoop.fs.FileSystem.access$200(FileSystem.java:93)
	at org.apache.hadoop.fs.FileSystem$Cache.getInternal(FileSystem.java:2680)
	at org.apache.hadoop.fs.FileSystem$Cache.get(FileSystem.java:2662)
	at org.apache.hadoop.fs.FileSystem.get(FileSystem.java:379)
	at org.apache.hadoop.fs.Path.getFileSystem(Path.java:296)
	at org.apache.flume.sink.hdfs.BucketWriter$1.call(BucketWriter.java:243)
	at org.apache.flume.sink.hdfs.BucketWriter$1.call(BucketWriter.java:235)
	at org.apache.flume.sink.hdfs.BucketWriter$9$1.run(BucketWriter.java:679)
	at org.apache.flume.auth.SimpleAuthenticator.execute(SimpleAuthenticator.java:50)
	at org.apache.flume.sink.hdfs.BucketWriter$9.call(BucketWriter.java:676)
	at java.util.concurrent.FutureTask$Sync.innerRun(FutureTask.java:334)
	at java.util.concurrent.FutureTask.run(FutureTask.java:166)
	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1110)
	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:603)
	at java.lang.Thread.run(Thread.java:722)
Caused by: java.net.UnknownHostException: nameservice1
```

将hadoop的core-site.xml和hdfs-site.xml文件放到FLUME_HOME/conf目录即可。

