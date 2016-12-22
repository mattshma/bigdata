在使用 HBase 的过程，想查看整个请求的处理时间，并为了方便以后做权限控制等，决定在 HBase 前加个 nginx。

安装 Nginx
---

### 下载模块依赖的包
先yum安装如下包：
`yum -y install openssl-devel zlib-devel pcre-devel`，若yum中没有相关源，需依次下载并安装[ssl](http://www.openssl.org/source/)，[zlib](http://zlib.net/)，[pcre](http://www.pcre.org/)，[substitutions](https://github.com/yaoweibin/ngx_http_substitutions_filter_module)。

对于部分环境，可能还需要安装perl的几个包：`yum -y install perl-devel perl-ExtUtils-Embed`。
### 编译并安装 nginx
如下：
```
$ ./configure --sbin-path=/usr/sbin/nginx --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --http-client-body-temp-path=/var/lib/nginx/tmp/client_body --http-proxy-temp-path=/var/lib/nginx/tmp/proxy --http-fastcgi-temp-path=/var/lib/nginx/tmp/fastcgi --http-uwsgi-temp-path=/var/lib/nginx/tmp/uwsgi --pid-path=/var/run/nginx.pid --lock-path=/var/lock/subsys/nginx --with-http_ssl_module --with-http_realip_module --with-http_addition_module --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_gzip_static_module --with-http_stub_status_module --with-http_perl_module --with-mail --with-mail_ssl_module --add-module=/root/software/nginx-1.6.2/modules/ngx_http_substitutions_filter_module --with-openssl=/root/software/nginx-1.6.2/modules/openssl-1.0.1j --with-openssl-opt=enable-tlsext --with-pcre=/root/software/nginx-1.6.2/modules/pcre-8.36

...

Configuration summary
  + using PCRE library: //root/software/nginx-1.6.2/modules/pcre-8.36
  + using OpenSSL library: /root/software/nginx-1.6.2/modules/openssl-1.0.1j
  + md5: using OpenSSL library
  + sha1: using OpenSSL library
  + using system zlib library

  nginx path prefix: "/usr/local/nginx"
  nginx binary file: "/usr/sbin/nginx"
  nginx configuration prefix: "/etc/nginx"
  nginx configuration file: "/etc/nginx/nginx.conf"
  nginx pid file: "/var/run/nginx.pid"
  nginx error log file: "/var/log/nginx/error.log"
  nginx http access log file: "/var/log/nginx/access.log"
  nginx http client request body temporary files: "/var/lib/nginx/tmp/client_body"
  nginx http proxy temporary files: "/var/lib/nginx/tmp/proxy"
  nginx http fastcgi temporary files: "/var/lib/nginx/tmp/fastcgi"
  nginx http uwsgi temporary files: "/var/lib/nginx/tmp/uwsgi"
  nginx http scgi temporary files: "scgi_temp"

# make;make install
```

nginx 配置
---
这里给 HBase 的 RESTServer 做个反向代理。其中 `/etc/nginx/nginx.conf` 如下：

```
user  hbase;
worker_processes  8;

error_log  /var/log/nginx/error.log  notice;

pid        /var/run/nginx.pid;

events {
    worker_connections  20480;
}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    log_format  main  '$request_time\t$upstream_response_time\t$remote_addr\t$upstream_addr\t[$time_local]\t'
                      '$host\t$request\t$status\t$bytes_sent\t'
                      '$http_referer\t$http_user_agent\t$gzip_ratio\t$http_x_forwarded_for\t$server_addr';

    access_log  /data/logs/nginx/access.log  main;

    sendfile        on;
    tcp_nopush      on;

    keepalive_timeout  10;
    tcp_nodelay        on;

    server_tokens   off;

    gzip  on;
    gzip_types  text/css text/javascript application/x-javascript text/xml application/xml;
    gzip_proxied any;
    gzip_vary on;

    client_max_body_size 10m;
    client_body_buffer_size 1m;
    client_body_temp_path /dev/shm;

    include /etc/nginx/conf.d/*.conf;

}
```

`/etc/nginx/conf.d/upstream.conf` 如下：
```
upstream hbase-rest-server {
    server 10.10.x.x:20550;
}
```
`/etc/nginx/conf.d/hbase.conf` 如下：

```
server {
    listen    80;

    location / {
        proxy_pass http://hbase-rest-server;
    }
}
```

增加限制
---
为了保证安全，不应该在任何地方都能通过rest做一些危险操作，需要增加限制，如下：

```
server {
        listen 80;
        location / {
            proxy_pass  http://hbase-rest-server;
        }

        location ~ /schema$ {
            proxy_pass http://hbase-rest-server;

            limit_except GET POST{
                allow 10.xx.xx.xx/32;
                allow 10.xx.xx.xx/32;
                deny all;
            }
        }
}
```

切割日志
---
设置logrotate来切割nginx日志，配置(/etc/logrotate.d/nginx)如下：

```
/data1/logs/nginx/*.log {
    daily
    rotate 30
    compress
    dateext
    sharedscripts
    postrotate
        kill -USR1 `cat /var/run/nginx.pid`
    endscript
}
```

REST测试
---
启动nginx后，可以开始测试rest。若这里nginx的机器为10.10.3.2。


### Create table

新建表 `test`， ColumnFamily为 'data'

```
curl -v -X PUT "10.10.3.2/test/schema" \
-H "Accept: application/json" \
-H "Content-Type: application/json" \
-d '{"@name": "test_name", "ColumnSchema": [{"name": "cf"}]}'
```

此时查看 test 表的 schema，如下：

```
% curl 10.10.3.2/test/schema
{ NAME=> 'test', @name => 'test_name', IS_META => 'false', COLUMNS => [ { NAME => 'cf', DATA_BLOCK_ENCODING => 'NONE', BLOOMFILTER => 'ROW', REPLICATION_SCOPE => '0', VERSIONS => '1', COMPRESSION => 'NONE', MIN_VERSIONS => '0', TTL => '2147483647', KEEP_DELETED_CELLS => 'false', BLOCKSIZE => '65536', IN_MEMORY => 'false', BLOCKCACHE => 'true' } ] }%      
```

### Put 

原始字符串 | base64编码
----------|---------
r1        | cjE=
cf:c1     | Y2Y6YzEK
c1_data   | YzFfZGF0YQo=


```
 curl -H "Accept: application/json" -H "Content-Type: application/json" -X PUT 10.10.3.2/test/r1/cf:c1 -d '{"Row": [{"key": "cjE=", "Cell": [{"column": "Y2Y6YzE=", "$": "YzFfZGF0YQ=="}]}]}'
```

### Get


```
curl 10.10.3.2/test/r1/cf:c1
<?xml version="1.0" encoding="UTF-8" standalone="yes"?><CellSet><Row key="cjE="><Cell column="Y2Y6YzE=" timestamp="1414737113822">YzFfZGF0YQ==</Cell></Row></CellSet>%                                             
```

在 HBase shell 中也可以看到：

```
hbase(main):012:0> get 'test', 'r1'
COLUMN                                  CELL                                                                                                            
 cf:c1                                  timestamp=1414737113822, value=c1_data                                                                          
1 row(s) in 0.0080 seconds
```

### Delete table

删除表 `test`

```
curl -X DELETE "10.10.3.2/test/schema"
```

附录
---
日志中格式说明:

- $request_time  
请求处理时间，从 client 端接收第一个字节到请求响应的最后一个字节发送到 client 端后再写入日志为止，单位秒，精度为毫秒。

- $upstream_response_time  
以毫秒的精度保留服务器的响应时间，单位是秒。 出现多个响应时，以逗号和冒号隔开。

- $remote_addr  
client 地址。

- $request_length  
请求长度，包括请求行，header, body。

- $upstream_addr   
保存服务器的IP地址和端口或者是UNIX域套接字的路径。 在请求处理过程中，如果有多台服务器被尝试了，它们的地址会被拼接起来，以逗号隔开，比如： “192.168.1.1:80, 192.168.1.2:80, unix:/tmp/sock”。 如果在服务器之间通过“X-Accel-Redirect”头或者error_page有内部跳转，那么这些服务器组之间会以冒号隔开，比如：“192.168.1.1:80, 192.168.1.2:80, unix:/tmp/sock : 192.168.10.1:80, 192.168.10.2:80”。

- $time_local  
通用日志格式下的本地时间。

- $host   
“Host”请求头的值，如果没有该请求头，则为与请求对应的虚拟主机的首要主机名。

- $request  
完整的原始请求行。

- $status  
响应状态码。

- $bytes_sent  
nginx返回给客户端的字节数。

- $http_<i>name</i>       
任意请求头的值；后面的 _name_ 为请求头中相应字段的小写字母，并使用 "_" 来代替中划线。

- $gzip_ratio   
gzip 的压缩比例。

- $server_addr   
接受请求的服务器地址。为计算这个值，通常需要进行一次系统调用。为了避免系统调用，必须指定 `listen` 指令的地址，并且使用 `bind` 参数。

- $server\_port    
接受请求的虚拟主机的端口。

- $cookie\_<i>name</i>    
名为 \_name\_ 的cookie。

- $sent_http\_<i>name</i>     
任意响应头的值；后面的 \_name\_ 为响应头中相应字段的小写字母，并使用 "_" 来代替中划线。



