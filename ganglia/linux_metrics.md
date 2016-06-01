# Linux Server监控项

监控做为基础服务，对问题发现和日常排错起到很好的作用。对于各种应用而言，精准正确的监控显得格外重要。一般而言，应该监控哪些项呢？

## CPU
###  上下文切换   
  在监控Linux应用时，当CPU利用率很高时，系统性能仍然上不去的话，可以看下是否由于上下文切换过于频繁。若确实上下文切换频繁，可通过[latencytop](http://blog.yufeng.info/archives/1239)或者pidstat来查看由哪些进程引起的。

### 中断  
  中断分为硬中断和软中断。频繁的中断会消耗一些cpu资源，通常而言中断默认集中在cpu0上（通过`cat /proc/interrupts`查看），一旦系统繁忙，该cpu会成为瓶颈。在SMP架构中，可通过其affinity技术将信号分散到不同的cpu上。
 
### 运行队列    
  当内核要寻找新进程在cpu上执行时，只能考虑处于可运行状态的进程，由于扫描整个进程列表相当低效，所以引入了可运行状态进程的双向循环链表，也叫运行队列。正在运行的进程数加运行队列的长度（即等待cpu的进程数），即平时所说的load。load反映了CPU的负载情况。

### CPU使用率   
CPU使用率有如下7种情况：
- idle   
 闲置cpu时间百分比。
 user   
 用户使用的cpu时间百分比。
- system        
 系统使用的cpu时间百分比。
- nice      
 改变过优先级的进程使用的CPU时间百分比。
- iowait   
 等待io完成使用的cpu时间百分比。
- irq     
 响应硬中断使用的cpu时间百分比。
- softirq    
 响应软中断使用的cpu时间百分比。

通过读取`/proc/stat`等文件可查看cpu运行情况，/proc/stat说明见[这里](http://www.linuxhowtos.org/System/procstat.htm)。也可通过其他如vmstat, dstat, sar等查看。top命令中，%wa高，说明磁盘忙；%si高，说明软中断多。

## Memory
内存主要分为实际物理内存和swap两部分，内存监控项如下：

- 总内存大小
- 已使用内存大小
- buffer
- cache
- free
- 可用内存大小
- 总swap大小
- 使用swap大小
- swap in
- swap out
- 内存条是否损坏

参过free或vmstat可监控得到。

## Disk
### 磁盘使用率
包括如下监控项：

- 每块盘总大小
- 每块盘已使用量
- 每块盘可用量

通过df可查看。

### I/O
- 每秒I/O次数
- I/O rate，即每秒读写吞吐量
- io util
- I/O请求队列长度
- 磁盘服务时间，即磁盘读写操作执行的时间，包括寻道，旋转数据传输时间。
- io wait，磁盘读写等待时间，即在队列中排除的时间

通过iostat和sar查看。另外，可自行计算IOPS。

### inode
包括如下项：

- inode总数
- 已使用inode数
- inode可用数

通过`df -i`可以看到各盘的inode情况。

### 磁盘是否损坏
megacli或SMART监控。Raid阵列是否有问题。

## Network
各网口的网络监控项如下：
- byte sent
- byte recv
- packets sent
- packets recv
- dropped packets sent
- dropped packets recv
- frame alignment errors sent
- frame alignment errors recv

可通过[Linux Network Statistics Tools / Commands](http://www.cyberciti.biz/faq/network-statistics-tools-rhel-centos-debian-linux/)来查看。

## Task
### 进程数
当前总的进程数，运行队列中的进程数，等待中的进程数，Sleep进程数。

## PageCache
对于Kafka服务，还需要PageCache的情况，详见Kafka监控项。

## 服务监控
- ntp
- nfs
- httpd
- mysqld
- nginx
- redis

服务的监控可监控其对应的端口。

## 其他
- 机器重启
- 机器关机
- 其他不太重要项如CPU风扇转速，CPU温度，磁盘温度的监控。

针对上述监控，也可通过python中的[psutil模块](https://pythonhosted.org/psutil/)来统一获得。

## Reference
- [linux-performance-monitoring-intro](http://www.thegeekstuff.com/2011/03/linux-performance-monitoring-intro/)
- [Monitoring HPC Systems: Processor and Memory Metrics](http://www.admin-magazine.com/HPC/Articles/Processor-and-Memory-Metrics)
- [Monitoring HPC Systems: Process, Network, and Disk Metrics](http://www.admin-magazine.com/HPC/Articles/Process-Network-and-Disk-Metrics)

