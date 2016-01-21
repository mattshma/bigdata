WebHDFS vs HttpFS
---

HDFS提供Java Native API用以高效的访问HDFS，对于Hadoop集群外的客户端访问Hadoop集群，不大可能都去安装hadoop和java库。所以为解决这一问题，出现了WebHDFS和HttpFS。HttpFS由cloudera开发并捐给Apache，WebHDFS由hortonworks开发并捐给Apache。

相同点
===
- 目的都是让Hadoop集群外的应用程序，不需要安装Java和Hadoop库，即可访问访问集群。
- 都通过HTTP方法支持Hadoop的读写操作，可用于代替HFTP（只读文件系统，通常配合distcp用于不同版本的Hadoop集群间拷贝数据）。
- 提供了一套REST API操作，该API不随Hadoop版本变化而变化，能在不同版本的Hadoop集群间拷贝数据。两者REST API能兼容。
- 都支持kerbose等验证方式。

不同点
===
- WebHDFS通过HTTP方法支持Hadoop所有操作，如读写文件和创建目录等。
- WebHDFS有 **Data Locality** 的特性，对HDFS文件的读写，会重定向到文件所在的DataNode，并会完全利用HDFS的带宽。
- 目前WebHDFS已是HDFS的内置组件。而HttpFS还需要单独启动该服务。
- HttpFS相当于一个gateway的功能，对于大流量的应用，HttpFS可能会是瓶颈。对于一些非核心用户，正好需要通过HttpfFS来限制带宽。

应用
===
当业务部门需要使用Hadoop集群时，可使用HttpFS服务。而在大批量拷贝数据时，可通过开启多个WebHDFS进程完全利用带宽来加速拷贝。

参考
===
- [WebHDFS – HTTP REST Access to HDFS](http://zh.hortonworks.com/blog/webhdfs-%E2%80%93-http-rest-access-to-hdfs/)
- [Hadoop HDFS over HTTP - Documentation Sets 2.0.0-cdh4.7.0](http://archive.cloudera.com/cdh4/cdh/4/hadoop/hadoop-hdfs-httpfs/index.html)
- [Accessing HDFS using the WebHDFS REST API](https://www.linkedin.com/pulse/20140717115238-176301000-accessing-hdfs-using-the-webhdfs-rest-api-vs-httpfs)
- [About HttpFS](http://www.cloudera.com/documentation/archive/cdh/4-x/4-7-1/CDH4-Installation-Guide/cdh4ig_topic_25_1.html)
- [WebHDFS REST API](https://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-hdfs/WebHDFS.html)
