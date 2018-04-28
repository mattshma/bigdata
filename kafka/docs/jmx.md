# Kafka 开启 JMX
其实很简单，编辑 `bin/kafka-server-start.sh` 脚本，查看是否有如下行：
```
export JMX_PORT=${JMX_PORT:-9999}
```

即当 `JMX_PORT` 为 null 或空字符串时，该值为 9999，若需要调整为其他端口，只需要在该行前面给 JMX_PORT 赋值即可。添加完成后，保存退出，重启 Kafka 即可。

打开 jconsole，输入 `service:jmx:rmi:///jndi/rmi://<IP>:<PORT>/jmxrmi`，如下图：

![connect](../img/jmx_1.jpg)

![info](../img/jmx_2.jpg)
