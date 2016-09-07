## Java NIO 

*注：本文主要参考[Java NIO Tutorial](http://tutorials.jenkov.com/java-nio/index.html)*。

在Java SE1.4之前，Java io主要为阻塞io，其主要分为character streams 和 byte streams，还有其他如Console, File, StreamTokenizer等接口。而character straem又可分为Reader和Writer两类，byte stream分为InputStream和OutputStream。

Java IO面向流，每次从流中读取一个或多个字节，并且是阻塞的，因此在Java SE1.4之前Java在处理IO方面比较弱，在Java SE1.4中引入了nio，其面向块且是非阻塞的，主要分为Buffer, Channel, Selector三块，另外还有charset。这里主要说下NIO方面的内容。

### NIO概述

如上所述，NIO主要分为Buffer，Channel和Selector。其关系如下：

```
                        /------> Channel <--------> Buffer
                        |
Thread ---> Selector ---|------> Channel <--------> Buffer
                        |
                        `------> Channel <--------> Buffer
```

Selector允许单线程处理多个Channel。

### Channel
既能从Channel中读取数据，也能写数据到Channel，主要有如下几种重要的Channel实现：
- FileChannel    
  从文件中读写数据。
- DatagramChannel    
  通过NDP读写网络数据报中的数据。
- SocketChannel    
  通过TCP读写网络数据报中的数据。
- ServerSocketChannel      
  监听新进来的TCP连接，对每个新进来的连接都会创建一个SocketChannel。

Java NIO支持scatte/gather，scatter从Channel中读取指将读取的数据写入多个Buffer中。gatter写入Channel指将多个Buffer的数据写入同一个Channel。Channel间数据可以通过`transferFrom()`和`transferTo()`互相传输。

### Buffer
使用Buffer读写数据，一般遵循如下四个步骤：
- 写数据到Buffer
- 调用`flip()`将Buffer从写模式切到读模式。
- 从Buffer中读取数据。
- 调用`clear()`或`compact()`清空缓冲区。`clear()`清空整个缓冲区，`compact()`只清除已经读过的数据。

Buffer有三个属性：
- capacity
- position
- limit

position和limit的含义取决于Buffer处于读模式或写模式。capacity即Buffer容量，一旦满了需要清空才能继续写数据。position表示当前位置，当数据写入buffer后，position向前移动到下一个可写入数据的Buffer单元中工，读取时position也会向前移动到下一个可读的位置。若从写模式切换到读模式，position会被重置为0。在写/读模式中，limit表示最多还能往/从Buffer写/读多少数据，从写模式切换到读模式时，limit会被设置成写模式下的position值。

### Selector
通过Selector可向多个Channel中读写数据，Channel须先注册到Selector才能与之使用，使用Selector的Channel须处于非阻塞模式下，即FileChannel不能与Selector配置使用，因其不能切换到非阻塞模式。如下是Channel注册到Selector的例子：
```
// 创建Selector
Selector selector = Selector.open();
// channel设置为非阻塞模式
channel.configureBlocking(false);
// channel注册到Selector上
SelectionKey key = channel.register(selector, SelectionKey.SelectionKey.OP_READ | SelectionKey.OP_WRITE);
```

通过register()向Selector注册后会返回一个SelectionKey对象。其有如下属性：

- interest集合     
  所选择的操作的集合：主要有OP_CONNECT，OP_ACCEPT，OP_READ，OP_WRITE等。
- ready集合     
  Channel是否准备好的集群。
- Channel     
  通过SelectionKey访问Channel：`Channel  channel  = selectionKey.channel();`。
- Selector     
  通过SelectionKey访问Selector：`Selector selector = selectionKey.selector();`。
- 附加的对象      
  将更多对象或信息通过attach()方法附加到SelectionKey上。

注册过后，可通过Selector的`select()`方法选中已经准备好的通道。用完Selector后需要调用其`close()`将其关闭。

其他更多内容此不详述。若希望更加深入了解这部分内容，可看下netty等的实现。

## 参考
- [Java nio vs Javaio](https://blogs.oracle.com/slc/entry/javanio_vs_javaio)
- [java io api](https://docs.oracle.com/javase/7/docs/api/java/io/package-summary.html)
- [java nio api](https://docs.oracle.com/javase/7/docs/api/java/nio/package-summary.html)
