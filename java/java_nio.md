# Java NIO vs. IO
在JDK1.4之前，Java io主要为io。其分为如下几类：

主要分为
character streams 和 byte streams，其他如Console, File, StreamTokenizer等接口。而character straem又可分为Reader和Writer两类，byte stream分为InputStream和OutputStream。

io与nio有什么差别呢？或nio哪些地方胜过io呢？

阻塞与非阻塞？

nio主要分为buffer, channel, selector三块，另外还有charset。


## 参考
- [Java nio vs Javaio](https://blogs.oracle.com/slc/entry/javanio_vs_javaio)
- [java io api](https://docs.oracle.com/javase/7/docs/api/java/io/package-summary.html)
- [java nio api](https://docs.oracle.com/javase/7/docs/api/java/nio/package-summary.html)
