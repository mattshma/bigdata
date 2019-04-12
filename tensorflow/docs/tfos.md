# TensorFlow On Spark 测试

## 测试过程

### 环境准备
注：当前 USER 为 admin 用户。

环境准备过程如下：
```
mkdir Python
wget https://www.python.org/ftp/python/2.7.15/Python-2.7.15.tgz
tar xvzf Python-2.7.15.tgz
sudo yum install -y zlib-devel openssl-devel libffi-devel
rm Python-2.7.15.tgz 
export PYTHON_ROOT=~/Python
pushd Python-2.7.15
./configure --prefix="${PYTHON_ROOT}" --enable-unicode=ucs4
make -j4; make install
popd
rm -rf Python-2.7.15/

// install pip
pushd ${PYTHON_ROOT}
wget --no-check-certificate https://bootstrap.pypa.io/get-pip.py
bin/python get-pip.py
rm get-pip.py
bin/pip install tensorflow tensorflowonspark pydoop

// create python.zip
zip -r Python.zip *
popd

// copy this Python distribution into HDFS
hdfs dfs -mkdir /user/${USER}/tfos
hdfs dfs -put ${PYTHON_ROOT}/Python.zip /user/${USER}/tfos

// run mnist
cd ~
mkdir mnist
pushd mnist
wget http://yann.lecun.com/exdb/mnist/train-images-idx3-ubyte.gz
wget http://yann.lecun.com/exdb/mnist/train-labels-idx1-ubyte.gz
wget http://yann.lecun.com/exdb/mnist/t10k-images-idx3-ubyte.gz
wget http://yann.lecun.com/exdb/mnist/t10k-labels-idx1-ubyte.gz
zip -r mnist.zip *
popd

// get tensorflow on spark
git clone https://github.com/yahoo/TensorFlowOnSpark.git
pushd TensorFlowOnSpark/
zip -r tfspark.zip tensorflowonspark
popd 

// get ecosystem jar
git clone https://github.com/tensorflow/ecosystem.git
cd ecosystem/hadoop
// 可能需要修改 pom.xml
mvn clean package
mvn install
hdfs dfs -put target/tensorflow-hadoop-1.10.0.jar /user/${USER}/tfos
```

环境准备好后，在开始试用前，还有几个环境变量需要设置，由于 TensorFlow 需要 `libcuda*.so`, `libjvm.so`, `libhdfs.so`，所以需要将这些库的路设置到 `spark.executorEnv.LD_LIBRARY_PATH` 中，若没有 `libhdfs.so`，还需编译该文件，可参考[这里](https://github.com/mattshma/bigdata/blob/master/hadoop/hdfs/build_libhdfs_so.md)，若不是 GPU 机器，则不需设置 `libcuda*.so` 库的路径。
```
export PYTHON_ROOT=Python
export LD_LIBRARY_PATH=${PATH}
export PYSPARK_PYTHON=${PYTHON_ROOT}/bin/python
export SPARK_YARN_USER_ENV="PYSPARK_PYTHON=Python/bin/python"
export PATH=${PYTHON_ROOT}/bin:$PATH
export LIB_HDFS=$HADOOP_PREFIX/lib/native    
export LIB_JVM=$JAVA_HOME/jre/lib/amd64/server
```

### feed_dict

- convert mnist to csv
```
cd ~
// 1. save images and labels as CSV files
${SPARK_HOME}/bin/spark-submit \
--master yarn \
--deploy-mode cluster \
--num-executors 4 \
--executor-memory 4G \
--archives hdfs:///user/${USER}/tfos/Python.zip#Python,mnist/mnist.zip#mnist \
--conf spark.yarn.appMasterEnv.PYSPARK_PYTHON=Python/bin/python \
TensorFlowOnSpark/examples/mnist/mnist_data_setup.py \
--output tfos/mnist/csv \
--format csv

// check csv result
hdfs dfs -du -h /user/admin/tfos/mnist/csv
3.9 M   11.8 M  /user/admin/tfos/mnist/csv/test
23.7 M  71.0 M  /user/admin/tfos/mnist/csv/train

hdfs dfs -ls /user/${USER}/tfos/mnist/csv/train/images
Found 11 items
-rw-r--r--   3 admin hadoop          0 2019-04-09 19:03 /user/admin/tfos/mnist/csv/train/images/_SUCCESS
-rw-r--r--   3 admin hadoop    2088387 2019-04-09 19:03 /user/admin/tfos/mnist/csv/train/images/part-00000.snappy
-rw-r--r--   3 admin hadoop    2505571 2019-04-09 18:54 /user/admin/tfos/mnist/csv/train/images/part-00001.snappy
-rw-r--r--   3 admin hadoop    2496056 2019-04-09 18:54 /user/admin/tfos/mnist/csv/train/images/part-00002.snappy
-rw-r--r--   3 admin hadoop    2490576 2019-04-09 18:54 /user/admin/tfos/mnist/csv/train/images/part-00003.snappy
-rw-r--r--   3 admin hadoop    2480417 2019-04-09 18:54 /user/admin/tfos/mnist/csv/train/images/part-00004.snappy
-rw-r--r--   3 admin hadoop    2493865 2019-04-09 18:54 /user/admin/tfos/mnist/csv/train/images/part-00005.snappy
-rw-r--r--   3 admin hadoop    2500594 2019-04-09 18:54 /user/admin/tfos/mnist/csv/train/images/part-00006.snappy
-rw-r--r--   3 admin hadoop    2510390 2019-04-09 19:03 /user/admin/tfos/mnist/csv/train/images/part-00007.snappy
-rw-r--r--   3 admin hadoop    2507386 2019-04-09 18:54 /user/admin/tfos/mnist/csv/train/images/part-00008.snappy
-rw-r--r--   3 admin hadoop    2338101 2019-04-09 18:54 /user/admin/tfos/mnist/csv/train/images/part-00009.snappy
```

- train

```
${SPARK_HOME}/bin/spark-submit \
--master yarn \
--deploy-mode cluster \
--num-exeuctors 5 \
--executor-memory 7G \
--py-files TensorFlowOnSpark/tfspark.zip,TensorFlowOnSpark/examples/mnist/spark/mnist_dist.py \
--conf spark.dynamicAllocation.enabled=false \
--conf spark.yarn.maxAppAttempts=1 \
--archives hdfs:///user/${USER}/tfos/Python.zip#Python \
--conf spark.yarn.appMasterEnv.PYSPARK_PYTHON=Python/bin/python \
--conf spark.executorEnv.LD_LIBRARY_PATH=$LIB_JVM:$LIB_HDFS \
TensorFlowOnSpark/examples/mnist/spark/mnist_spark.py \
--images tfos/mnist/csv/train/images \
--labels tfos/mnist/csv/train/labels \
--mode train \
--model tfos/mnist/mnist_model_csv 
```

- inference
```
${SPARK_HOME}/bin/spark-submit \
--master yarn \
--deploy-mode cluster \
--num-exeuctors 5 \
--executor-memory 7G \
--py-files TensorFlowOnSpark/tfspark.zip,TensorFlowOnSpark/examples/mnist/spark/mnist_dist.py \
--conf spark.dynamicAllocation.enabled=false \
--conf spark.yarn.maxAppAttempts=1 \
--archives hdfs:///user/${USER}/tfos/Python.zip#Python \
--conf spark.yarn.appMasterEnv.PYSPARK_PYTHON=Python/bin/python \
--conf spark.executorEnv.LD_LIBRARY_PATH=$LIB_JVM:$LIB_HDFS \
TensorFlowOnSpark/examples/mnist/spark/mnist_spark.py \
--images tfos/mnist/csv/test/images \
--labels tfos/mnist/csv/test/labels \
--mode inference \
--model tfos/mnist/mnist_model_csv \
--output tfos/mnist/predictions_csv
```

### QueueRunners

```
// 1. save image and label as TFRecords
${SPARK_HOME}/bin/spark-submit \
--master yarn \
--deploy-mode cluster \
--num-executors 5 \
--executor-memory 7G \
--archives hdfs:///user/${USER}/tfos/Python.zip#Python,mnist/mnist.zip#mnist \
--conf spark.yarn.appMasterEnv.PYSPARK_PYTHON=Python/bin/python \
--jars hdfs:///user/${USER}/tfos/tensorflow-hadoop-1.10.0.jar \
TensorFlowOnSpark/examples/mnist/mnist_data_setup.py \
--output tfos/mnist/tfr \
--format tfr

// check tfrecords
hdfs dfs -du -h /user/admin/tfos/mnist/tfr
3.0 M   9.0 M   /user/admin/tfos/mnist/tfr/test
18.1 M  54.3 M  /user/admin/tfos/mnist/tfr/train

hdfs dfs -ls /user/admin/tfos/mnist/tfr/train
Found 11 items
-rw-r--r--   3 admin hadoop          0 2019-04-09 20:08 /user/admin/tfos/mnist/tfr/train/_SUCCESS
-rw-r--r--   3 admin hadoop    1623109 2019-04-09 20:07 /user/admin/tfos/mnist/tfr/train/part-r-00000.snappy
-rw-r--r--   3 admin hadoop    1948345 2019-04-09 20:07 /user/admin/tfos/mnist/tfr/train/part-r-00001.snappy
-rw-r--r--   3 admin hadoop    1941474 2019-04-09 20:08 /user/admin/tfos/mnist/tfr/train/part-r-00002.snappy
-rw-r--r--   3 admin hadoop    1941070 2019-04-09 20:08 /user/admin/tfos/mnist/tfr/train/part-r-00003.snappy
-rw-r--r--   3 admin hadoop    1933293 2019-04-09 20:07 /user/admin/tfos/mnist/tfr/train/part-r-00004.snappy
-rw-r--r--   3 admin hadoop    1937368 2019-04-09 20:08 /user/admin/tfos/mnist/tfr/train/part-r-00005.snappy
-rw-r--r--   3 admin hadoop    1946743 2019-04-09 20:07 /user/admin/tfos/mnist/tfr/train/part-r-00006.snappy
-rw-r--r--   3 admin hadoop    1950499 2019-04-09 20:07 /user/admin/tfos/mnist/tfr/train/part-r-00007.snappy
-rw-r--r--   3 admin hadoop    1948750 2019-04-09 20:07 /user/admin/tfos/mnist/tfr/train/part-r-00008.snappy
-rw-r--r--   3 admin hadoop    1813753 2019-04-09 20:07 /user/admin/tfos/mnist/tfr/train/part-r-00009.snappy

// 2. train
// 注意，这里的 `mnist_dist.py` 为 `examples/mnist/tf` 下的文件，而非 `examples/mnist/spark` 目录下的文件。
${SPARK_HOME}/bin/spark-submit \
--master yarn \
--deploy-mode cluster \
--num-exeuctors 5 \
--executor-cores 1 \
--executor-memory 7G \
--py-files TensorFlowOnSpark/tfspark.zip,TensorFlowOnSpark/examples/mnist/tf/mnist_dist.py \
--conf spark.dynamicAllocation.enabled=false \
--conf spark.yarn.maxAppAttempts=1 \
--archives hdfs:///user/${USER}/tfos/Python.zip#Python \
--conf spark.yarn.appMasterEnv.PYSPARK_PYTHON=Python/bin/python \
--conf spark.executorEnv.LD_LIBRARY_PATH=$LIB_JVM:$LIB_HDFS \
TensorFlowOnSpark/examples/mnist/tf/mnist_spark.py \
--cluster_size 5 \
--images tfos/mnist/tfr/train \
--format tfr \
--mode train \
--model tfos/mnist/mnist_model_tfr 

// 3. inference
${SPARK_HOME}/bin/spark-submit \
--master yarn \
--deploy-mode cluster \
--num-executors 5 \
--executor-cores 1 \
--executor-memory 7G \
--py-files TensorFlowOnSpark/tfspark.zip,TensorFlowOnSpark/examples/mnist/tf/mnist_dist.py \
--conf spark.dynamicAllocation.enabled=false \
--conf spark.yarn.maxAppAttempts=1 \
--archives hdfs:///user/${USER}/tfos/Python.zip#Python \
--conf spark.yarn.appMasterEnv.PYSPARK_PYTHON=Python/bin/python \
--conf spark.executorEnv.LD_LIBRARY_PATH=$LIB_JVM:$LIB_HDFS \
TensorFlowOnSpark/examples/mnist/tf/mnist_spark.py \
--images tfos/mnist/tfr/test \
--mode inference \
--model mnist_model \
--output tfos/mnist/predictions_QueueRunners
```

### Spark Streaming

```
// 1. save image and label as csv2
${SPARK_HOME}/bin/spark-submit \
--master yarn \
--deploy-mode cluster \
--num-executors 5 \
--executor-memory 7G \
--archives hdfs:///user/${USER}/tfos/Python.zip#Python,mnist/mnist.zip#mnist \
--conf spark.yarn.appMasterEnv.PYSPARK_PYTHON=Python/bin/python \
TensorFlowOnSpark/examples/mnist/mnist_data_setup.py \
--output tfos/mnist/csv2 \
--format csv2

hdfs dfs -ls /user/admin/tfos/mnist/csv2
Found 2 items
drwxr-xr-x   - admin admin          0 2019-04-12 14:02 /user/admin/tfos/mnist/csv2/test
drwxr-xr-x   - admin admin          0 2019-04-12 14:02 /user/admin/tfos/mnist/csv2/train

// 2. train

${SPARK_HOME}/bin/spark-submit \
--master yarn \
--deploy-mode cluster \
--num-executors 5 \
--executor-cores 1 \
--executor-memory 7G \
--py-files TensorFlowOnSpark/tfspark.zip,TensorFlowOnSpark/examples/mnist/streaming/mnist_dist.py \
--conf spark.dynamicAllocation.enabled=false \
--conf spark.yarn.maxAppAttempts=1 \
--conf spark.streaming.stopGracefullyOnShutdown=true \
--archives hdfs:///user/${USER}/tfos/Python.zip#Python \
--conf spark.yarn.appMasterEnv.PYSPARK_PYTHON=Python/bin/python \
--conf spark.executorEnv.LD_LIBRARY_PATH=$LIB_JVM:$LIB_HDFS \
TensorFlowOnSpark/examples/mnist/streaming/mnist_spark.py \
--images tfos/mnist/stream_data \
--format csv2 \
--mode train \
--model tfos/mnist/mnist_model_sparkstreaming

// create a folder tor streaming data
hdfs dfs -mkdir temp tfos/mnist/stream_data
hdfs dfs -cp tfos/mnist/csv2/train/* temp

hdfs dfs -ls temp
Found 11 items
-rw-r--r--   3 admin admin          0 2019-04-12 14:30 temp/_SUCCESS
-rw-r--r--   3 admin admin    2097383 2019-04-12 14:30 temp/part-00000.snappy
-rw-r--r--   3 admin admin    2516332 2019-04-12 14:30 temp/part-00001.snappy
-rw-r--r--   3 admin admin    2506875 2019-04-12 14:30 temp/part-00002.snappy
-rw-r--r--   3 admin admin    2502118 2019-04-12 14:30 temp/part-00003.snappy
-rw-r--r--   3 admin admin    2492699 2019-04-12 14:30 temp/part-00004.snappy
-rw-r--r--   3 admin admin    2504341 2019-04-12 14:30 temp/part-00005.snappy
-rw-r--r--   3 admin admin    2511424 2019-04-12 14:30 temp/part-00006.snappy
-rw-r--r--   3 admin admin    2521416 2019-04-12 14:30 temp/part-00007.snappy
-rw-r--r--   3 admin admin    2518163 2019-04-12 14:30 temp/part-00008.snappy
-rw-r--r--   3 admin admin    2348851 2019-04-12 14:30 temp/part-00009.snappy

hdfs dfs -mv temp/part-00000.snappy tfos/mnist/stream_data
hdfs dfs -mv temp/part-00001.snappy tfos/mnist/stream_data
hdfs dfs -mv temp/part-0000[2-9].snappy tfos/mnist/stream_data

// kill streaming application
yarn application -kill <Spark-Streaming-Application>


// 3. inference
hdfs dfs -rmr /user/admin/tfos/mnist/stream_data/* temp/*

/opt/app/spark-2.2.0/bin/spark-submit --master yarn --deploy-mode cluster --num-executors 5 --executor-cores 1 --executor-memory 7G --py-files TensorFlowOnSpark/tfspark.zip,TensorFlowOnSpark/examples/mnist/streaming/mnist_dist.py --conf spark.dynamicAllocation.enabled=false --conf spark.yarn.maxAppAttempts=1 --conf spark.streaming.stopGracefullyOnShutdown=true --archives hdfs:///user/${USER}/tfos/Python.zip#Python --conf spark.yarn.appMasterEnv.PYSPARK_PYTHON=Python/bin/python --conf spark.executorEnv.LD_LIBRARY_PATH=$LIB_JVM:$LIB_HDFS TensorFlowOnSpark/examples/mnist/streaming/mnist_spark.py --images tfos/mnist/stream_data --format csv2 --mode inference --model tfos/mnist/mnist_model_sparkstreaming --output tfos/mnist/predictions_sparkstreaming

hdfs dfs -cp tfos/mnist/csv2/test/* temp

hdfs dfs -ls temp
Found 11 items
-rw-r--r--   3 admin admin          0 2019-04-12 14:51 temp/_SUCCESS
-rw-r--r--   3 admin admin     397751 2019-04-12 14:52 temp/part-00000.snappy
-rw-r--r--   3 admin admin     398649 2019-04-12 14:52 temp/part-00001.snappy
-rw-r--r--   3 admin admin     402505 2019-04-12 14:52 temp/part-00002.snappy
-rw-r--r--   3 admin admin     403696 2019-04-12 14:52 temp/part-00003.snappy
-rw-r--r--   3 admin admin     396118 2019-04-12 14:52 temp/part-00004.snappy
-rw-r--r--   3 admin admin     411732 2019-04-12 14:52 temp/part-00005.snappy
-rw-r--r--   3 admin admin     412621 2019-04-12 14:52 temp/part-00006.snappy
-rw-r--r--   3 admin admin     417258 2019-04-12 14:52 temp/part-00007.snappy
-rw-r--r--   3 admin admin     420919 2019-04-12 14:52 temp/part-00008.snappy
-rw-r--r--   3 admin admin     420446 2019-04-12 14:52 temp/part-00009.snappy

hdfs dfs -mv temp/part-00000.snappy tfos/mnist/stream_data
hdfs dfs -mv temp/part-00001.snappy tfos/mnist/stream_data
hdfs dfs -mv temp/part-0000[2-9].snappy tfos/mnist/stream_data

// kill streaming application
yarn application -kill <Spark-Streaming-Application>

```

## 报错

### 'AutoProxy[get_queue]' object has no attribute 'put'
执行 `$ ${SPARK_HOME}/bin/spark-submit --master yarn --deploy-mode cluster --num-executors 4 --executor-memory 4G --archives hdfs:///user/${USER}/tfos/Python.zip#Python,mnist/mnist.zip#mnist --jars hdfs:///user/${USER}/tfos/tensorflow-hadoop-1.10.0.jar TensorFlowOnSpark/examples/mnist/mnist_data_setup.py --output tfos/mnist/tfr --format tfr` 时报错如下：
```
[Stage 0:=========>         (1 + 1) / 2][Stage 1:>                 (0 + 5) / 10]19/04/09 20:26:11 TRACE MessageDecoder: Received message OneWayMessage: OneWayMessage{body=NettyManagedBuffer{buf=CompositeByteBuf(ridx: 5, widx: 9530, cap: 9530, components=17)}}
19/04/09 20:26:11 TRACE MessageDecoder: Received message OneWayMessage: OneWayMessage{body=NettyManagedBuffer{buf=CompositeByteBuf(ridx: 5, widx: 10529, cap: 10529, components=3)}}
19/04/09 20:26:11 INFO TaskSetManager: Starting task 5.0 in stage 1.0 (TID 7, svr11929hw2288.hadoop.sh2.ctripcorp.com, executor 2, partition 5, ANY, 5457 bytes)
19/04/09 20:26:11 INFO TaskSetManager: Starting task 6.0 in stage 1.0 (TID 8, svr11929hw2288.hadoop.sh2.ctripcorp.com, executor 2, partition 6, ANY, 5457 bytes)
19/04/09 20:26:11 TRACE MessageDecoder: Received message OneWayMessage: OneWayMessage{body=NettyManagedBuffer{buf=PooledUnsafeDirectByteBuf(ridx: 13, widx: 1669, cap: 65536)}}
19/04/09 20:26:11 TRACE MessageDecoder: Received message OneWayMessage: OneWayMessage{body=NettyManagedBuffer{buf=PooledUnsafeDirectByteBuf(ridx: 13, widx: 1669, cap: 65536)}}
19/04/09 20:26:11 WARN TaskSetManager: Lost task 2.0 in stage 1.0 (TID 4, svr11929hw2288.hadoop.sh2.ctripcorp.com, executor 2): org.apache.spark.api.python.PythonException: Traceback (most recent call last):
  File "/opt/data/10/yarn/local/usercache/admin/appcache/application_1549945841103_0043/container_e60_1549945841103_0043_01_000003/pyspark.zip/pyspark/worker.py", line 177, in main
    process()
  File "/opt/data/10/yarn/local/usercache/admin/appcache/application_1549945841103_0043/container_e60_1549945841103_0043_01_000003/pyspark.zip/pyspark/worker.py", line 172, in process
    serializer.dump_stream(func(split_index, iterator), outfile)
  File "/opt/data/10/yarn/local/usercache/admin/appcache/application_1549945841103_0043/container_e60_1549945841103_0043_01_000001/pyspark.zip/pyspark/rdd.py", line 2423, in pipeline_func
  File "/opt/data/10/yarn/local/usercache/admin/appcache/application_1549945841103_0043/container_e60_1549945841103_0043_01_000001/pyspark.zip/pyspark/rdd.py", line 2423, in pipeline_func
  File "/opt/data/10/yarn/local/usercache/admin/appcache/application_1549945841103_0043/container_e60_1549945841103_0043_01_000001/pyspark.zip/pyspark/rdd.py", line 2423, in pipeline_func
  File "/opt/data/10/yarn/local/usercache/admin/appcache/application_1549945841103_0043/container_e60_1549945841103_0043_01_000001/pyspark.zip/pyspark/rdd.py", line 346, in func
  File "/opt/data/10/yarn/local/usercache/admin/appcache/application_1549945841103_0043/container_e60_1549945841103_0043_01_000001/pyspark.zip/pyspark/rdd.py", line 794, in func
  File "/opt/data/10/yarn/local/usercache/admin/appcache/application_1549945841103_0043/container_e60_1549945841103_0043_01_000001/tfspark.zip/tensorflowonspark/TFSparkNode.py", line 406, in _train
AttributeError: 'AutoProxy[get_queue]' object has no attribute 'put'

	at org.apache.spark.api.python.PythonRunner$$anon$1.read(PythonRDD.scala:193)
	at org.apache.spark.api.python.PythonRunner$$anon$1.<init>(PythonRDD.scala:234)
	at org.apache.spark.api.python.PythonRunner.compute(PythonRDD.scala:152)
	at org.apache.spark.api.python.PythonRDD.compute(PythonRDD.scala:63)
	at org.apache.spark.rdd.RDD.computeOrReadCheckpoint(RDD.scala:323)
	at org.apache.spark.rdd.RDD.iterator(RDD.scala:287)
	at org.apache.spark.scheduler.ResultTask.runTask(ResultTask.scala:87)
	at org.apache.spark.scheduler.Task.run(Task.scala:108)
	at org.apache.spark.executor.Executor$TaskRunner.org$apache$spark$executor$Executor$TaskRunner$$runInternal(Executor.scala:353)
	at org.apache.spark.executor.Executor$TaskRunner.run(Executor.scala:296)
	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1142)
	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:617)
	at java.lang.Thread.run(Thread.java:745)

```
参考 [issue-248](https://github.com/yahoo/TensorFlowOnSpark/issues/248)，修改 executor core 为 1，即 `--num-executors 1`。


### ImportError: No module named tensorflow
报错如下：
```
Traceback (most recent call last):
  File "mnist_data_setup.py", line 10, in <module>
    import tensorflow as tf
ImportError: No module named tensorflow
```

添加 `--conf spark.yarn.appMasterEnv.PYSPARK_PYTHON=Python/bin/python`，如下：
```
/opt/app/spark-2.2.0/bin/spark-submit --master yarn --deploy-mode cluster --num-executors 4 --executor-memory 4G --archives hdfs:///user/${USER}/tfos/Python.zip#Python,mnist/mnist.zip#mnist --conf spark.yarn.appMasterEnv.PYSPARK_PYTHON=Python/bin/python TensorFlowOnSpark/examples/mnist/mnist_data_setup.py --output tfos/mnist/csv --format csv
```

### AssertionError: TensorFlow cluster requires at least one worker or master/chief node
报错如下：
```
args: Namespace(batch_size=100, cluster_size=1, epochs=1, format='csv', images='tfos/mnist/csv/train/images', labels='tfos/mnist/csv/train/labels', mode='train', model='mnist_model', output='predictions', rdma=False, readers=1, steps=1000, tensorboard=False)
2019-04-10T19:18:54.448000 ===== Start
zipping images and labels
2019-04-10 19:18:55,139 INFO (MainThread-187860) Reserving TFSparkNodes 
Traceback (most recent call last):
  File "mnist_spark.py", line 64, in <module>
    cluster = TFCluster.run(sc, mnist_dist.map_fun, args, args.cluster_size, num_ps, args.tensorboard, TFCluster.InputMode.SPARK)
  File "/opt/data/7/yarn/local/usercache/admin/appcache/application_1545705600094_64220/container_1545705600094_64220_01_000001/tfspark.zip/tensorflowonspark/TFCluster.py", line 249, in run
AssertionError: TensorFlow cluster requires at least one worker or master/chief node
```

由于 `AttributeError: 'AutoProxy[get_queue]' object has no attribute 'put'` 的报错，将 `executor-cores` 设置为了 1，导致出了这个问题，查看 [TFCluster.py](https://github.com/yahoo/TensorFlowOnSpark/blob/v1.4.3/tensorflowonspark/TFCluster.py#L249)，debug 了下，发现 num_master, num_eval, num_workers 均为 0，查看源码上下文，知可设置 `--cluster_size`，去掉 `--executor-cores 1` 后，设置 `--cluster_size 5`，运行成功。


###  No TFManager found on this node

报错如下：
```
Exception: No TFManager found on this node, please ensure that:
1. Spark num_executors matches TensorFlow cluster_size
2. Spark cores/tasks per executor is 1.
3. Spark dynamic allocation is disabled.
```

设置 `--executor-cores 1` 和 `--num-executors` 大小等于 `--cluster_size`。
 
### DataLossError: corrupted record at X
```
19/04/11 15:28:46 WARN TaskSetManager: Lost task 1.0 in stage 0.0 (TID 1, executor 2): org.apache.spark.api.python.PythonException: Traceback (most recent call last):
  File "/opt/data/7/yarn/local/usercache/admin/appcache/application_1545705600094_64706/container_1545705600094_64706_01_000004/pyspark.zip/pyspark/worker.py", line 177, in main
    process()
  ...
  File "/opt/data/7/yarn/local/usercache/admin/appcache/application_1545705600094_64706/container_1545705600094_64706_01_000004/Python/lib/python2.7/site-packages/tensorflow/python/client/session.py", line 1348, in _do_call
    raise type(e)(node_def, op, message)
DataLossError: corrupted record at 0
	 [[node IteratorGetNext (defined at /opt/data/7/yarn/local/usercache/admin/appcache/application_1545705600094_64706/container_1545705600094_64706_01_000004/__pyfiles__/mnist_dist.py:101) ]]
```

看报错，是生成的 tfr 文件有问题。但通过 `TensorFlowOnSpark/examples/mnist/mnist_data_setup.py` 的 `--read` 参数读取了下数据，是正常的。待解决。
