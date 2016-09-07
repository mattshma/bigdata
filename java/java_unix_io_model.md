# Java与unix的I/O模型

## Unix I/O模型

Unix下有五种I/O模型：
- 阻塞I/O (blocking I/O model)
- 非阻塞I/O (nonblocking I/O model)
- I/O复用 (I/O multiplexing model: select 和poll)
- 信号驱动式I/O (signal-driven I/O model)
- 异步I/O (asynchronous I/O model)

在数据写入时，这些模型主要在如下两方面有区别：
- 等待数据准备。
- 将数据从内核拷贝到进程。

以下具体说下这5种模式。

### 阻塞I/O模型
最常见的I/O模型即阻塞I/O模型，默认情况下，所有的socket都是阻塞的。如下是阻塞I/O的流程：

![阻塞I/O模型图](img/java_io_model/blocking_io.png)

如上图所示，当进程调用`recfrom`时，直到数据准备好再将数据从内核拷贝给进程空间并返回，进程才继续执行，否则会一直阻塞。

### 非阻塞I/O模型
当socket设置为非阻塞时，如果数据未准备好，内核会返回错误代码`EWOULDBLOCK`不让进程处于sleep状，I/O流程如下：

![非阻塞I/O模型图](img/java_io_model/nonblocking_io.png)

- 对于前3个`recvfrom`，由于数据还未准备好，内核返回错误`EWOULDBLOCK`。
- 当第4次调用`recvfrom`，数据已准备好，于是数据从内核拷贝到进程空间中，进程阻塞直到内核返回结果。

如上图，非阻塞I/O模型中进程会主动循环的调用`recvfrom`询问数据是否准备好，这称为 **polling**。非阻塞I/O比较浪费CPU时间，因此不太常用，一般是在其他I/O模型中使用非阻塞I/O这一特性。

### I/O复用模型
I/O复用会使用到`select`和`poll`两个函数，这两个函数也会使用线程阻塞，但同阻塞I/O不同的是，这两个函数会同时阻塞多个I/O操作且同时对多读写的函数进行检测，直到有数据可用时，才真正调用I/O操作函数。流程如下：

![I/O复用模型](img/java_io_model/io_multiplexing.png)

用户调用select，那么整个进程被select调用（而不是socket IO）block，同时内核会监听所有select负表的socket，当任何一个socket数据准备好了，select会返回，此时用户进程再调用`recvfrom`，将数据从内核拷贝到进程空间。

I/O复用看起来和阻塞I/O差不多，由于I/O复用会使用两次系统调用（select和recvfrom），而阻塞I/O只使用一次系统调用（recvfrom），看起来I/O复用更差。其实不然，select的优势在于能同时处理多个连接。

同I/O复用模型比较类似的是多进程加阻塞I/O模型这个组合。区别在于I/O复用是使用一个select调用block多个阻塞，而多进程加阻塞I/O是每个进程被一个系统调用阻塞（如redvfrom）。

### 信号驱动I/O模型

信号驱动I/O模型使用信号`SIGIO`来通知数据准备好了。如下图：

![信号驱动I/O模型](img/java_io_model/signal_driven_io.png)

- 首先允许socket使用信号驱动，然后使用`sigaction`系统调用安装信号处理函数，接着立即返回，这样进程不会被阻塞。
- 当数据准备好后，内核返回`SIGIO`信号给进程。在拷贝数据给进程过程中，进程阻塞。

信号驱动一般不太常用。

### 异步I/O模型
进程发起系统调用后可立即返回。当内核将数据拷贝到进程空间后再通知进程去取，整体过程如下：

![异步I/O模型](img/java_io_model/asyn_io.png)


### I/O模式比较

如下图：

![IO模型对比](img/java_io_model/comparison.png)

前四种I/O只要是第一阶段（即数据阶段）不同，第二阶段都会阻塞进程。而异步I/O不会阻塞进程。

### 同步与异步

POSIX对于同步I/O和异步I/O的定义如下：

- 同步I/O即阻塞进程直到I/O操作完成。
- 异步I/O不会阻塞进程。

按这个定义，前面四种I/O都是同步I/O模型。只有异步I/O模型是异步I/O。





## 参考
- [Chapter 6. I/O Multiplexing: The select and poll Functions](https://notes.shichao.io/unp/ch6/)
