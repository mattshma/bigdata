# Flume相关的一些笔记

## Source

若source为kafka，其已存在数据，若希望flume重头开始("from-begingin")读取数据，可通过重新设置新comsume组来实现。若zookeeper中偏移数据为空或便宜数据进出范围，可通过设置[auto.offset.reset](https://kafka.apache.org/08/configuration.html#consumerconfigs)为`smallest`或`readSmallestOffset`为`true`来重头读取。



