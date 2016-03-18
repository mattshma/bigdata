# Flume相关的一些笔记

## Source

若source为kafka，其已存在数据，若希望flume重头开始("from-begingin")读取数据，需设置`auto.offset.reset`为`smallest`或`readSmallestOffset`为`true`。默认情况下若source为kafka，flume会从当前最大offset读取。


