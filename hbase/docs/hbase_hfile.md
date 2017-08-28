# HBase HFile 分析

网上查了下，


## 工具
$ ${HBASE_HOME}/bin/hbase org.apache.hadoop.hbase.io.hfile.HFile  
usage: HFile  [-a] [-b] [-e] [-f <arg>] [-k] [-m] [-p] [-r <arg>] [-v] 
-a,--checkfamily    Enable family check 
-b,--printblocks    Print block index meta data 
-e,--printkey       Print keys 
-f,--file <arg>     File to scan. Pass full-path; e.g. 
                     hdfs://a:9000/hbase/.META./12/34 
-k,--checkrow       Enable row order check; looks for out-of-order keys 
-m,--printmeta      Print meta data of file 
-p,--printkv        Print key/value pairs 
-r,--region <arg>   Region to scan. Pass region name; e.g. '.META.,,1' 
-v,--verbose        Verbose output; emits file and meta data delimiters 


## 参考
- [HFile format](http://hbase.apache.org/1.2/book.html#_hfile_format_2)
- [Apache HBase I/O – HFile](http://blog.cloudera.com/blog/2012/06/hbase-io-hfile-input-output/)
- [HFile.java](https://github.com/apache/hbase/blob/branch-1.2/hbase-server/src/main/java/org/apache/hadoop/hbase/io/hfile/HFile.java)
- [HBASE-11729](https://issues.apache.org/jira/browse/HBASE-11729)
