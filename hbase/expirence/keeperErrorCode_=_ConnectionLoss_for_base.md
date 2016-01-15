报错
---

```bash
ERROR [main] client.HConnectionManager$HConnectionImplementation: Can't get connection to ZooKeeper: KeeperErrorCode = ConnectionLoss for /hbase
ERROR [main] zookeeper.RecoverableZooKeeper: ZooKeeper exists failed after 4 attempts
WARN  [main] zookeeper.ZKUtil: hconnection-0x766245a4, quorum=localhost:2181, baseZNode=/hbase Unable to set watcher on znode (/hbase)
org.apache.zookeeper.KeeperException$ConnectionLossException: KeeperErrorCode = ConnectionLoss for /hbase
```

出现这种情况原因都是hbase无法连接zookeeper。个人碰到有如下情况导致该问题。

## 先关HMaster，但未关REST服务，再启动HMaster报错

启动zkCli.zh，报错如下：
```
INFO  [main-SendThread(localhost:2181):ClientCnxn$SendThread@966] - Opening socket connection to server localhost/127.0.0.1:2181. Will not attempt to authenticate using SASL (Unable to locate a login configuration)
2015-11-04 17:50:49,334 [myid:] - WARN  [main-SendThread(localhost:2181):ClientCnxn$SendThread@1089] - Session 0x0 for server null, unexpected error, closing socket connection and attempting reconnect
java.net.ConnectException: Connection refused
    at sun.nio.ch.SocketChannelImpl.checkConnect(Native Method)
    at sun.nio.ch.SocketChannelImpl.finishConnect(SocketChannelImpl.java:599)
    at org.apache.zookeeper.ClientCnxnSocketNIO.doTransport(ClientCnxnSocketNIO.java:350)
    at org.apache.zookeeper.ClientCnxn$SendThread.run(ClientCnxn.java:1068)
```

由于没zookeeper日志，于是查看hbase的日志，报错如下：
```
WARN  [NIOServerCxn.Factory:0.0.0.0/0.0.0.0:2181] server.NIOServerCnxnFactory: Too many connections from /127.0.0.1 - max is 300
WARN  [NIOServerCxn.Factory:0.0.0.0/0.0.0.0:2181] server.NIOServerCnxnFactory: Too many connections from /127.0.0.1 - max is 300
WARN  [main] zookeeper.RecoverableZooKeeper: Possibly transient ZooKeeper, quorum=localhost:2181, exception=org.apache.zookeeper.KeeperException$ConnectionLossException: KeeperErrorCode = ConnectionLoss for /hbase
ERROR [main] zookeeper.RecoverableZooKeeper: ZooKeeper create failed after 4 attempts
```
想到rest服务还没关，于是kill进程后，重启hbase master，成功。再启动REST服务即可。

## zookeeper服务器防火墙未关闭
在zookeeper服务器上关闭防火墙即可。

