# Ganglia搭建

## 安装Python
下载python后，安装如下：

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

## 安装Gmetad 

下载ganglia后，将其解压在`/opt`目录：

```
# tar ganglia-3.7.2.tar.gz -C /opt
# cd /opt
# ln -s ganglia-3.7.2 ganglia
# cd ganglia
# ./configure --prefix=/usr/local/ganglia --enable-setuid=ganglia --enable-setgid=ganglia --enable-perl  --enable-status --with-gmetad --with-python=/usr
/local/python --sysconfdir=/etc/ganglia
# make
# make install
```

由于ganglia不是默认安装路径，因此需要修改`/opt/ganglia/gmetad/gmetad.init`中的`GMETAD=/usr/sbin/gmetad`为`GMETAD=/usr/local/ganglia/sbin/gmetad`，`/opt/ganglia/gmond/gmond.init`类似。然后将启动脚本拷贝到`/etc/init.d`目录下

```
# cp /opt/ganglia/gmetad/gmetad.init /etc/init.d/gmetad
# cp /opt/ganglia/gmond/gmond.init /etc/init.d/gmond
```

## 安装ganglia-web 和 ganglia-webfront

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
