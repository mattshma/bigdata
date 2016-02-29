## SocketTimeoutException: 70000 millis timeout while waiting for channel to be ready for read

### 背景
通过Flume往HDFS写数据，但日志中一直报如下错误：

```
java.net.SocketTimeoutException: 70000 millis timeout while waiting for channel to be ready for read. ch : java.nio.channels.SocketChannel[connected local=/10.2.96.9:17268 remote=/10.2.96.43:50010]
        at org.apache.hadoop.net.SocketIOWithTimeout.doIO(SocketIOWithTimeout.java:164)
        at org.apache.hadoop.net.SocketInputStream.read(SocketInputStream.java:161)
        at org.apache.hadoop.net.SocketInputStream.read(SocketInputStream.java:131)
        at org.apache.hadoop.net.SocketInputStream.read(SocketInputStream.java:118)
        at java.io.FilterInputStream.read(FilterInputStream.java:83)
        at java.io.FilterInputStream.read(FilterInputStream.java:83)
        at org.apache.hadoop.hdfs.protocolPB.PBHelper.vintPrefixed(PBHelper.java:1986)
        at org.apache.hadoop.hdfs.DFSOutputStream$DataStreamer.transfer(DFSOutputStream.java:1063)
        at org.apache.hadoop.hdfs.DFSOutputStream$DataStreamer.addDatanode2ExistingPipeline(DFSOutputStream.java:1031)
        at org.apache.hadoop.hdfs.DFSOutputStream$DataStreamer.setupPipelineForAppendOrRecovery(DFSOutputStream.java:1175)
        at org.apache.hadoop.hdfs.DFSOutputStream$DataStreamer.processDatanodeError(DFSOutputStream.java:924)
        at org.apache.hadoop.hdfs.DFSOutputStream$DataStreamer.run(DFSOutputStream.java:486)
16/02/29 15:47:59 INFO hdfs.BucketWriter: Close tries incremented
16/02/29 15:47:59 WARN hdfs.BucketWriter: Closing file: hdfs://youzu-hadoop/user/datacenter/hive/warehouse/raw_scribe_log.db/est/ds=20160226/game_id=142/log.1456456819249.tmp failed. Will retry again in 180 seconds.
```
一直重试，导致flume占用内存增加。

### 分析
集群运行正常，客户端与Hadoop集群的读写都是通过DFSClient进行的，因此猜测是`dfs.client.socket-timeout`这个参数设置（默认值为60s）太低导致。重启Flume，指定`-Ddfs.client.socket-timeout=120000`。

