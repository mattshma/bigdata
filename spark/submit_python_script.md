# Spark 提交 python 脚本

提交 python 脚本时，可能报错：`ImportError: No module name xxxx`。

解决方法：
正确生成 zip 的方法：
```
$ cd my-folder
$ zip -r ../my-folder.zip .
```
这样 spark 在解压时，需要的文件会出现在解压目录第一层（即 my-folder 下各文件直接出现在 spark 解压目录下，而不是 my-folder 目录中）。

如下做法是错误的：
```
$ zip -r my-folder.zip my-folder/*
```

或在代码中将文件加到 `SparkContext` 中，如下：
```
sc.addPyFile(file_path)
```

说明：--py-files 和 --archives 等区别。

## 参考
- [How-to: Prepare Your Apache Hadoop Cluster for PySpark Jobs](https://blog.cloudera.com/blog/2015/09/how-to-prepare-your-apache-hadoop-cluster-for-pyspark-jobs/)
- [在spark上运行Python脚本遇到“ImportError: No module name xxxx”](https://blog.csdn.net/wangxiao7474/article/details/81391300)
- [I can't seem to get --py-files on Spark to work](https://stackoverflow.com/questions/36461054/i-cant-seem-to-get-py-files-on-spark-to-work)
- [PySpark dependencies](http://blog.danielcorin.com/code/2015/11/10/pyspark.html)
- [Hadoop DistributedCache详解](http://dongxicheng.org/mapreduce-nextgen/hadoop-distributedcache-details/)
