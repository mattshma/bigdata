java.lang.OutOfMemoryError: unable to create new native thread
====

### 现象
报上述错时，系统内存还有10G的空闲。报错的原因不是JVM内存够，而是分配组jvm native thread内存不够了。

## 分析
出现以上情况，从两方面分析：JVM设置和系统设置。以下分别说明。

### 操作系统限制
查看报错用户的`ulimit -u`情况，若太小的话需要修改，对于Redhat/Centos用户修改`/etc/security/limits.d/90-nproc.conf`文件。格式为`*    -    nproc     4096`。因为报错为OutofMemoryError，说明还没达到操作系统限制。可通过`ps h -Lu USER_NAME | wc -l`或者`ps h -Led -o user | sort | uniq -c | sort -nr`检查。

### JVM设置
在java中，当创建一个线程时，虚拟机除了在jvm创建一个Thread对象外，还会在操作系统中创建一个native进程，该native thread使用的内存不是JVM的内存，而是系统剩余的内存。native thread能创建的个数可由下列公式估算：

```
(MaxProcessMemory - JVMMemory - ReservedOsMemory) / (ThreadStackSize) = Number of threads
```

看情况是要减少JVM的heap大小或者减少ThreadStackSize(`-Xss`)大小。

### 疑问
1. JVM thread和native thread的关系，ThreadStackSize设置大小对这两者的影响。
2. 其他JVM OutofMemoryError情况？见[揭开java.lang.OutOfMemoryError面纱之一](http://dongyajun.iteye.com/blog/622488)
3. JVM结构？？


### 参考
- [My application has a lot of threads and is running out of memory](http://www.oracle.com/technetwork/java/hotspotfaq-138619.html#threads_oom)
- [vmoptions](http://www.oracle.com/technetwork/java/javase/tech/vmoptions-jsp-140102.html)
- [Understanding Java and native thread details](https://www-01.ibm.com/support/knowledgecenter/SSYKE2_8.0.0/com.ibm.java.zos.80.doc/diag/tools/javadump_tags_javaandnative_thread_detail.html)
