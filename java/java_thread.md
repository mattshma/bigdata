# Java多线程

线程安全？

线程的几种状态

两者实现方式。

## wait sleep等方法区别


## synchronized
无论synchronized关键字加在方法上还是对象上，它取得的锁都是对象，而不是把一段代码或函数当作锁。在同步块中，锁的即synchronized的参数。对于静态同步方法，锁是针对这个类的，锁对象是该类的Class对象。


## ThreadLocal

## 线程池
使用线程池优点：
- 不用每次新建对象，效率更高。
- 方便管理，
- 功能丰富，支持定时执行等功能。
- 避免this逃逸问题。

### ExecutorService

Java支持如下线程池：
- newCachedThreadPool
- newFixedThreadPool
- newScheduledThreadPool
- newSingleThreadExecutor


## Callable和Future


