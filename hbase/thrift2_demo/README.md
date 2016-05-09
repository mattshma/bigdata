HBase Thrift2 Python Demo
---
通过thrift2(python)访问HBase。

TODO
===
- 多线程
- 随机字符串

安装Thrift
=== 

下载[thrift](http://thrift.apache.org/)后，安装即可。然后

```
# mkdir hbase_thrift2
# cd hbase_thrift2
# thrift --gen py /opt/cloudera/parcels/CDH/lib/hbase/include/thrift/hbase2.thrift
# pip install hbase-thrift
```

问题
===

- ImportError: cannot import name THBaseService   
使用`from hbase import THBaseService`报错，修改为如下：
```
sys.path.append(os.path.abspath('gen-py/hbase'))
from THBaseService import Client, TColumnValue, TPut, TGet
```
即可。

参考
===
- [ThriftApi](https://wiki.apache.org/hadoop/Hbase/ThriftApi)
- [DemoClient.py](https://github.com/apache/hbase/blob/master/hbase-examples/src/main/python/thrift2/DemoClient.py)
