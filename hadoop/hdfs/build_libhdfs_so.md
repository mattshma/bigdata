# 编译生成 libhdfs.so

git hadoop-hdfs 源码后。进入 `hadoop-hdfs/src`，然后执行 `cmake -DGENERATED_JAVAH=${JAVA_HOME} .`，然后执行 `make`，在 `target/usr/local/lib` 目录下可以看到生成的 libhdfs.so.0.0.0 文件。

然后将生成的 libhdfs.so.0.0.0 拷贝到 `$HADOOP_PREFIX/lib/native/` 目录中，再做个软链 libhdfs.so 指向该文件。
