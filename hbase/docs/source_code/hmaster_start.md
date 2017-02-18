# HMaster启动过程分析

__说明: 当前参考 HBase 版本为[1.2.5](https://github.com/apache/hbase/tree/branch-1.2)。__

在分析 HMaster 启动过程前，可以先在 IntelliJ 中启动 HMaster。通过打印出来的 log，可以大致知道启动顺序：
```
2017-02-16 14:38:37,589 INFO  [main] util.VersionInfo: HBase 1.2.5-SNAPSHOT
2017-02-16 14:38:38,684 INFO  [main] master.HMasterCommandLine: Starting a zookeeper cluster
2017-02-16 14:38:39,020 INFO  [main] server.ZooKeeperServer: Server environment:zookeeper.version=3.4.6-1569965, built on 0
2017-02-16 14:38:39,105 INFO  [main] server.NIOServerCnxnFactory: binding to port 0.0.0.0/0.0.0.0:2181
2017-02-16 14:38:39,381 INFO  [NIOServerCxn.Factory:0.0.0.0/0.0.0.0:2181] server.NIOServerCnxnFactory: Accepted socket connection from /127.0.0.1:59965
2017-02-16 14:38:39,400 INFO  [Thread-1] server.NIOServerCnxn: Stat command output
2017-02-16 14:38:39,404 INFO  [main] master.HMasterCommandLine: Starting up instance of localHBaseCluster; master=1, regionserversCount=1
2017-02-16 14:38:41,994 INFO  [main] regionserver.RSRpcServices: master//192.168.51.52:0 server-side HConnection retries=350
2017-02-16 14:38:42,926 INFO  [main] ipc.SimpleRpcScheduler: Using deadline as user call queue, count=3
2017-02-16 14:38:43,190 WARN  [main] impl.MetricsConfig: Cannot locate configuration: tried hadoop-metrics2-hbase.properties,hadoop-metrics2.properties
2017-02-16 14:38:43,296 INFO  [main] impl.MetricsSystemImpl: HBase metrics system started
2017-02-16 14:38:44,488 INFO  [main] zookeeper.RecoverableZooKeeper: Process identifier=master:59969 connecting to ZooKeeper ensemble=localhost:2181
2017-02-16 14:38:44,498 INFO  [main] zookeeper.ZooKeeper: Client environment:zookeeper.version=3.4.6-1569965, built on 02/20/2014 09:09 GMT
2017-02-16 14:38:44,964 INFO  [main] http.HttpServer: Added global filter 'safety' (class=org.apache.hadoop.hbase.http.HttpServer$QuotingInputFilter)
2017-02-16 14:38:45,693 INFO  [main] master.HMaster: Adding backup master ZNode /hbase/backup-masters/192.168.51.52,59969,1487227123340
2017-02-16 14:38:46,048 INFO  [main] regionserver.RSRpcServices: regionserver//192.168.51.52:0 server-side HConnection retries=350
2017-02-16 14:38:46,053 INFO  [main] ipc.RpcServer: regionserver//192.168.51.52:0: started 10 reader(s) listening on port=59974
...
```

## 分析
首先找到 HMaster 的 `main()`方法，其参数为 HBase 相关属性(minRegionServers, localRegionServers, masters, backup 四个属性)和 start, stop, clear 3个动作来执行相关操作。如下：
```
  public static void main(String [] args) {
    // 打印 HBase 版本信息
    VersionInfo.logVersion();
   //启动 HMasterCommandLine 的 doMain() 方法，该方法会调用 ToolRunner 类的 run() 方法，而 ToolRunner 类的 run() 调用 HMasterCommandLine 类的 run() 做为返回值。
    new HMasterCommandLine(HMaster.class).doMain(args);
  }
```

HMasterCommandLine 类的 run() 根据四个属性的传入值进行设置，并根据动作执行相应操作，如 start 动作对应 startMaster() 方法，clear 动作对应清除 zookeeper 中的 master znode。

这里分析 startMaster()。startMaster 分两种启动方式：本地模式和分布式模式。本地模式使用 LocalHBaseCluster 启动，分布式模式将使用反射，这里分析分布式模式下 HMaster 的启动：
```
public class HMasterCommandLine extends ServerCommandLine {

  private int startMaster() {
    // 省略本地模式代码和分布式模式下检查服务是否 stop 代码。
    ...
    // 反射生成 CoordinatedStateManager 对象实例。
    CoordinatedStateManager csm =
          CoordinatedStateManagerFactory.getCoordinatedStateManager(conf);
    // 通过反射调用 HMaster 的构造方法创建实例对象。HMaster --extends--> HRegionServer --extends--> HasThread --implements--> Runnable，所以 HMaster 也是线程。
    HMaster master = HMaster.constructMaster(masterClass, conf, csm);
    ...
    // 启动 master 线程。
    master.start();
    master.join();
    ...
  }
}
``` 

HMaster 构造函数调用父类 HRegionServer 构造函数，重点步骤如下：
```
public class HRegionServer extends HasThread implements
    RegionServerServices, LastSequenceId {

  public HRegionServer(Configuration conf, CoordinatedStateManager csm)
      throws IOException, InterruptedException {

    // 文件系统设置可用
    this.fsOk = true;
    this.conf = conf;
    // 通过 conf 设置初始化 userProvider
    this.userProvider = UserProvider.instantiate(conf);
    // 根据 conf 设置 Short Circuit Read
    FSUtils.setupShortCircuitRead(this.conf);
    // RegionServer 中关闭 Meta 表的 Read Replicas 特性
    this.conf.setBoolean(HConstants.USE_META_REPLICAS, false);
    // 读取 conf 中部分配置
    ...
    this.threadWakeFrequency = conf.getInt(HConstants.THREAD_WAKE_FREQUENCY, 10 * 1000);
    this.numRegionsToReport = conf.getInt(
      "hbase.regionserver.numregionstoreport", 10);
    this.operationTimeout = conf.getInt(
      HConstants.HBASE_CLIENT_OPERATION_TIMEOUT,
      HConstants.DEFAULT_HBASE_CLIENT_OPERATION_TIMEOUT);
    this.shortOperationTimeout = conf.getInt(
      HConstants.HBASE_RPC_SHORTOPERATION_TIMEOUT_KEY,
      HConstants.DEFAULT_HBASE_RPC_SHORTOPERATION_TIMEOUT);
    ...

    // 创建 RPC 服务
    rpcServices = createRpcServices();
    // 设置 serverName
    serverName = ServerName.valueOf(hostName, rpcServices.isa.getPort(), startcode);
    rpcControllerFactory = RpcControllerFactory.instantiate(this.conf);
    rpcRetryingCallerFactory = RpcRetryingCallerFactory.instantiate(this.conf);

    // login the zookeeper client principal (if using security)
    ZKUtil.loginClient(this.conf, HConstants.ZK_CLIENT_KEYTAB_FILE,
      HConstants.ZK_CLIENT_KERBEROS_PRINCIPAL, hostName);
    // login the server principal (if using secure Hadoop)
    login(userProvider, hostName);
    // 初始化超级用户
    Superusers.initialize(conf);
    ...
    // 根据 fs.defaultFS 设置初始化文件系统
    initializeFileSystem();

    // 新建 ExecutorService 对象，其类似于线程池。后续会做介绍
    service = new ExecutorService(getServerName().toShortString());
    // 设置 spanReceiverHost ，SpanReceiver 可参考 http://hbase.apache.org/book.html#tracing.spanreceivers 
    spanReceiverHost = SpanReceiverHost.getInstance(getConfiguration());

    if (!conf.getBoolean("hbase.testing.nocluster", false)) {
      // 连接 Zookeeper 服务并设置 primary watcher
      zooKeeper = new ZooKeeperWatcher(conf, getProcessName() + ":" +
        rpcServices.isa.getPort(), this, canCreateBaseZNode());

      // 初始化 BaseCoordinatedStateManager 并启动
      this.csm = (BaseCoordinatedStateManager) csm;
      this.csm.initialize(this);
      this.csm.start();

      // TableLockManager: A manager for distributed table level locks.
      tableLockManager = TableLockManager.createTableLockManager(
        conf, zooKeeper, serverName);

      // 监听 Zookeeper 上的 /master 这个 znode 目录
      masterAddressTracker = new MasterAddressTracker(getZooKeeper(), this);
      masterAddressTracker.start();

      // Tracker on cluster settings up in zookeeper
      clusterStatusTracker = new ClusterStatusTracker(zooKeeper, this);
      clusterStatusTracker.start();
    }
    // 配置管理器。若在线修改配置，其允许修改相关配置，而无需重启整个集群
    this.configurationManager = new ConfigurationManager();

    // 启动 RPC 服务
    rpcServices.start();
    // 启动 WebUI
    putUpWebUI();
    this.walRoller = new LogRoller(this, this);
    // 新建 ChoreService 对象，其能周期性调度 [ScheduledChore](https://hbase.apache.org/devapidocs/org/apache/hadoop/hbase/ScheduledChore.html)
    this.choreService = new ChoreService(getServerName().toString(), true);   
```

## 参考
