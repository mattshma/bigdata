## NameNode

### 介绍
TODO: 功能。保存的信息。

### NameNode启动流程

在命令行中启动 NameNode 的方法比较多，如 `sbin/hadoop-daemon.sh start namenode` 和 `sbin/start-dfs.sh` 等，这些方式最终调用 `bin/hdfs namenode` 启动 namenode。查看 `bin/hdfs` 文件，可以看到其在处理 namenode 变量时，指向的类是 `org.apache.hadoop.hdfs.server.namenode.NameNode`，以下从该类着手，分析 NameNode 启动过程。

[NameNode](https://github.com/apache/hadoop/blob/branch-2.7.3/hadoop-hdfs-project/hadoop-hdfs/src/main/java/org/apache/hadoop/hdfs/server/namenode/NameNode.java) 类如下：

```
public class NameNode implements NameNodeStatusMXBean {
  static{
    HdfsConfiguration.init();
  }
   
  ...

  public static final int DEFAULT_PORT = 8020;

  protected FSNamesystem namesystem; 

  /** httpServer */
  protected NameNodeHttpServer httpServer;

  private NameNodeRpcServer rpcServer;

  protected void initialize(Configuration conf) throws IOException {
    if (conf.get(HADOOP_USER_GROUP_METRICS_PERCENTILES_INTERVALS) == null) {
      String intervals = conf.get(DFS_METRICS_PERCENTILES_INTERVALS_KEY);
      if (intervals != null) {
        conf.set(HADOOP_USER_GROUP_METRICS_PERCENTILES_INTERVALS,
          intervals);
      }
    }

    UserGroupInformation.setConfiguration(conf);
    loginAsNameNodeUser(conf);

    NameNode.initMetrics(conf, this.getRole());
    StartupProgressMetrics.register(startupProgress);

    if (NamenodeRole.NAMENODE == role) {
      startHttpServer(conf);
    }

    this.spanReceiverHost =
      SpanReceiverHost.get(conf, DFSConfigKeys.DFS_SERVER_HTRACE_PREFIX);

    loadNamesystem(conf);

    rpcServer = createRpcServer(conf);
    if (clientNamenodeAddress == null) {
      // This is expected for MiniDFSCluster. Set it now using 
      // the RPC server's bind address.
      clientNamenodeAddress = 
          NetUtils.getHostPortString(rpcServer.getRpcAddress());
      LOG.info("Clients are to use " + clientNamenodeAddress + " to access"
          + " this namenode/service.");
    }
    if (NamenodeRole.NAMENODE == role) {
      httpServer.setNameNodeAddress(getNameNodeAddress());
      httpServer.setFSImage(getFSImage());
    }
    
    pauseMonitor = new JvmPauseMonitor(conf);
    pauseMonitor.start();
    metrics.getJvmMetrics().setPauseMonitor(pauseMonitor);
    
    startCommonServices(conf);
  }
  
  /**
   * Create the RPC server implementation. Used as an extension point for the
   * BackupNode.
   */
  protected NameNodeRpcServer createRpcServer(Configuration conf)
      throws IOException {
    return new NameNodeRpcServer(conf, this);
  }

  /** Start the services common to active and standby states */
  private void startCommonServices(Configuration conf) throws IOException {
    namesystem.startCommonServices(conf, haContext);
    registerNNSMXBean();
    if (NamenodeRole.NAMENODE != role) {
      startHttpServer(conf);
      httpServer.setNameNodeAddress(getNameNodeAddress());
      httpServer.setFSImage(getFSImage());
    }
    rpcServer.start();
    plugins = conf.getInstances(DFS_NAMENODE_PLUGINS_KEY,
        ServicePlugin.class);
    for (ServicePlugin p: plugins) {
      try {
        p.start(this);
      } catch (Throwable t) {
        LOG.warn("ServicePlugin " + p + " could not be started", t);
      }
    }
    LOG.info(getRole() + " RPC up at: " + rpcServer.getRpcAddress());
    if (rpcServer.getServiceRpcAddress() != null) {
      LOG.info(getRole() + " service RPC up at: "
          + rpcServer.getServiceRpcAddress());
    }
  }

  protected NameNode(Configuration conf, NamenodeRole role) 
      throws IOException { 
    this.conf = conf;
    this.role = role;
    setClientNamenodeAddress(conf);
    String nsId = getNameServiceId(conf);
    String namenodeId = HAUtil.getNameNodeId(conf, nsId);
    this.haEnabled = HAUtil.isHAEnabled(conf, nsId);
    state = createHAState(getStartupOption(conf));
    this.allowStaleStandbyReads = HAUtil.shouldAllowStandbyReads(conf);
    this.haContext = createHAContext();
    try {
      initializeGenericKeys(conf, nsId, namenodeId);
      initialize(conf);
      try {
        haContext.writeLock();
        state.prepareToEnterState(haContext);
        state.enterState(haContext);
      } finally {
        haContext.writeUnlock();
      }
    } catch (IOException e) {
      this.stop();
      throw e;
    } catch (HadoopIllegalArgumentException e) {
      this.stop();
      throw e;
    }
    this.started.set(true);
  }

  public static NameNode createNameNode(String argv[], Configuration conf)
      throws IOException {
    ...

    // 启动 NameNode 时的其余参数
    StartupOption startOpt = parseArguments(argv);

    switch (startOpt) {
      // 参数为格式化 NameNode
      case FORMAT: ...
      // 参数为产生新的 ClusterID
      case GENCLUSTERID: ...
      // 参数为升级
      case FINALIZE: ...
      // 回滚
      case ROLLBACK: ...
      case BOOTSTRAPSTANDBY: ...
      case INITIALIZESHAREDEDITS: ...
      case BACKUP: ...
      case CHECKPOINT: 
      case RECOVER: ...
      case METADATAVERSION: ...
      case UPGRADEONLY: ...
      default: {
        DefaultMetricsSystem.initialize("NameNode");
        return new NameNode(conf);
      }
    }
  }

  public static void main(String argv[]) throws Exception {
    ...
 
    try {
      NameNode namenode = createNameNode(argv, null);
      if (namenode != null) {
        namenode.join();
      }
    } 
    ...
  }

```
