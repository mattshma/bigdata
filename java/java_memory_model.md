# Java内存模型

## 什么是内存模型
内存模型定义了某一CPU写内存，其他CPU也对该数据可见的充要条件。由于如下几种情况的存在：

- CPU缓存。多核CPU系统中，CPU通常都有多层缓存结构。CPU直接操作的是缓存中的数据。在某些时刻，CPU缓存中的数据与内存中的数据可能存在不一致的情况。
- CPU指令[乱序执行](https://zh.wikipedia.org/wiki/%E4%B9%B1%E5%BA%8F%E6%89%A7%E8%A1%8C)。为避免CPU在运算对象不可获取时的大量等待，CPU会在某些改变指令的执行顺序。
- 编译器的代码重排。出于性能优化的考虑，在不改变程序语义的情况，编译器会对代码进行重排。

有必要对Java程序访问和操作主存的方式进行规范。[Java内存模型](http://www.cs.umd.edu/~pugh/java/memoryModel/)即为解决这个问题而引入的。一些CPU实现强内存模型，即任何时刻所有CPU见到内存中的值都一样的。一些CPU实现较弱的内存模型，通过内存屏障来刷新或过期CPU缓存的数据，来达到所有CPU看到的数据一致这一目的。Java内存模型描述了多线程代码中哪些行为是合法的，以及线程在内存的交互方式。

Java提供了一些语言级别的支持用以帮助多线程编程，如`volatile`，`final`，`synchronized`等关键字。Java内存模型定义了`volatile`和`synchronized`的行为，并且保证正确的synchronize代码能在所有CPU架构都能正确运行。

	



## 参考
- [Memory Model](https://docs.oracle.com/javase/specs/jls/se8/html/jls-17.html#jls-17.4)
- [JSR 133 (Java Memory Model) FAQ](http://www.cs.umd.edu/~pugh/java/memoryModel/jsr-133-faq.html)
- [Memory Barriers: a Hardware View for Software Hackers](http://www.puppetmastertrading.com/images/hwViewForSwHackers.pdf)
