# Ganglia搭建

## 准备工作
### 安装Python
若python版本不需要升级的，可跳过此步。下载python后，安装如下：

```
# ./configure --enable-shared --prefix=/usr/local/python CFLAGS=-fPIC
# make;make install
```

注意，若没加`CFLAGS=-fPIC`，在编译ganglia时，会报如下错：
```
/usr/bin/ld: /usr/local/lib/libpython2.7.a(abstract.o): relocation R_X86_64_  
32 against 'a local symbol' can not be used when making a shared object; rec  
ompile with -fPIC  
/usr/local/lib/libpython2.7.a: could not read symbols: Bad value  
```

### 安装依赖
下载libconfuse-devel-2.6-2.el6.rf.x86_64.rpm和libconfuse-2.6-2.el6.rf.x86_64.rpm并安装：
```
# rpm -ivh libconfuse-2.6-2.el6.rf.x86_64.rpm libconfuse-devel-2.6-2.el6.rf.x86_64.rpm
```

yum安装依赖如下：
````
# yum -y install perl-ExtUtils-Embed apr-devel expat-devel pcre-devel
````

## 安装

下载ganglia后，将其解压在用户根目录下：

```
# tar ganglia-3.7.2.tar.gz 
# cd ganglia-3.7.2
# ./configure --prefix=/opt/ganglia --enable-setuid=ganglia --enable-setgid=ganglia --enable-perl -enable-python --enable-status --with-gmetad --with-python=/usr
/local/python --sysconfdir=/etc/ganglia
# make
# make install
```

对于gmond节点，configure参数为`./configure --prefix=/opt/ganglia --enable-perl --enable-python --enable-status --sysconfdir=/etc/ganglia`。
若希望以ganglia用户运行监控进程的话，configure编译参数中还需要加`--enable-setuid=ganglia --enable-setgid=ganglia`，否则默认为nobody用户。

由于ganglia不是默认安装路径，因此需要修改`~/ganglia-3.7.2/gmetad/gmetad.init`中的`GMETAD=/usr/sbin/gmetad`为`GMETAD=/opt/ganglia/sbin/gmetad`，`~/ganglia-3.7.2/gmond/gmond.init`类似。然后将启动脚本拷贝到`/etc/init.d`目录下

```
# cp ~/ganglia-3.7.2/gmetad/gmetad.init /etc/init.d/gmetad
# cp ~/ganglia-3.7.2/gmond/gmond.init /etc/init.d/gmond
```

## 修改配置文件

### gmeta配置文件

gmetad的配置文件如下:

```
#debug_level 9
setuid_username "ganglia"
server_threads 10
case_sensitive_hostnames 0

rrd_rootdir "/data/ganglia/rrds"
gridname "YZ Hadoop"
data_source "Cluster One" 60 bd01-001 bd01-010
data_source "Cluster Two" 60 bd02-001 bd02-010
```

保证rrd_rootdir的拥有者为ganglia。data_source用来唯一标识一个集群或grid，格式为`data_source "my cluster" [polling interval] address1:port addreses2:port ...`，其中[polling interval]表示多久收集一次数，默认为15s，web frontend判断一台机器是否停机的标准是其TN(metric数据源最后一次更新到现在的秒数)时间少于4 * TMAX (默认20s)，因此，若设置的polling interval若大于80s的话，对于一台未宕机的机器，web frontend可能会误认为其宕机而显示出错。

### gmond配置文件

gmond的配置（可通过`/opt/ganglia/sbin/gmond -t > /etc/ganglia/gmond.conf`生成模板）如下：
```
globals {
  daemonize = yes
  setuid = no
  user = nobody
  debug_level = 0
  max_udp_msg_len = 1472
  mute = no
  deaf = no
  allow_extra_data = yes
  host_dmax = 86400 /*secs. Expires (removes from web interface) hosts in 1 day */
  host_tmax = 20 /*secs */
  cleanup_threshold = 300 /*secs */
  gexec = no
  send_metadata_interval = 30 /*secs */
}

cluster {
  name = "Cluster One"
  owner = "unspecified"
  latlong = "unspecified"
  url = "unspecified"
}

host {
  location = "unspecified"
}

udp_send_channel {
  bind_hostname = yes
  host = "bd01-001"
  port = 8649
  ttl = 1
}

udp_recv_channel {
  port = 8649
  buffer = 124928
}

tcp_accept_channel {
  port = 8649
  gzip_output = yes
}

```

注意cluster中的name要和gmetad中的data_source相同，若为单播模式，udp_send_channel中的host要同data_source中的host相同，若有端口信息，端口信息也必须相同。

#### globals
- mute       
boolean型，若为ture，则不管配置中其他指令如何，gmond都不会发送数据；

- deaf     
boolean型，若为ture，则不管配置中其他指令如何，gmond都不会接收数据。

- allow_extra_data     
boolean型，当值为false时，gmond将不会发送XML的EXTRA_ELEMENT和EXTRA_DATA部分。该值主要应用于用户使用自己的前端并希望节省带宽时。

- host_dmax    
以秒为单位的整数值，表示多久没接收到服务器数据，前端会删除该服务器，若为0，则表示永不删除。dmax为delete max的缩写。

- host_tmax           
以秒为单位的整数值，表示timeout 时间，tmax为timeout max的缩写，若4*`host_tmax`没收到主机数据，则认为该主机已崩溃。

- cleanup_threshold          
以秒为单位的整数值，表示清除过期数据的最小时间间隔。

- gexec   
boolean型，若为true，则gmond允许主机运行gexec任务。

- send_metadata_interval            
以秒为单位的整数值，表示发送元数据包的时间间隔，元数据包用来描述所有需要监控的监控项。若为0，则表示gmond只在启动和其他远程主机运行的gmond节点请求时都会发送元数据包。

#### cluster
- name    
集群名称，需和gmetad.conf中集群名称相同。

- owner      
集群管理员。

- latlong      
集群所在地区的经纬度。

#### host
- location     
用于标识主机位置，如Rack, Rank and Plane格式。


## 安装ganglia-web 和 ganglia-webfront
下载ganglia-webfront和ganglia-web，解压到/opt目录。配置httpd服务如下：
```
Alias /ganglia /opt/ganglia-webfrontend

<Location /ganglia>
  Order deny,allow
  # Deny from all
  Allow from all
</Location>
```
启动httpd服务。一段时间后，即可看到监控数据。

## 问题
### gmetad启动不了
通过`/etc/init.d/gmetad start`启动失败，可修改`/etc/ganglia/gmetad.conf`的log级别：`debug_level 9`，然后再启动，根据报错解决相关问题即可。相应的，若gmond出现导演，可修改`/etc/ganglia/gmond.conf`中的`debug_level`级别。

### 服务启动后没数据
在成功启动gmetad和gmond服务后，发现web上只有图形却没数据。查看`/var/log/messages`没异常。gmetad报错如下：
```
data_thread() for [my cluster] failed to contact node 127.0.0.1 
data_thread() got no answer from any [my cluster] datasource
```
gmond一直输出：
```
[tcp] Request for XML data received.
[tcp] Request for XML data completed.
[tcp] Request for XML data received.
[tcp] Request for XML data completed.
```

一般而言，从gmond输出可以看出，metrics没配置，所以没数据。由于最初gmond的配置文件参考[Ganglia-Quick-Start](https://github.com/ganglia/monitor-core/wiki/Ganglia-Quick-Start)，其未配置任何监控项，因此不会有数据，重新通过`/usr/local/ganglia/sbin/gmond -t > /etc/ganglia/gmond.conf`生成配置文件，修改部分参数即可。


## 参考
- [Ganglia Quick Start](https://github.com/ganglia/monitor-core/wiki/Ganglia-Quick-Start)
- [Monitoring Multiple Clusters using Ganglia](https://jablonskis.org/2011/monitoring-multiple-clusters-using-ganglia/index.html)
- [Introduction to Ganglia on Ubuntu 14.04](https://www.digitalocean.com/community/tutorials/introduction-to-ganglia-on-ubuntu-14-04)
