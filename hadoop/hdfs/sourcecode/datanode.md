# DataNode分析
源码目录结构为hadoop-hdfs-project/hadoop-hdfs/src/main/java/org/apache/hadoop/hdfs/server/datanode/DataNode.java。

## 介绍
DataNode是DFS分布式中的数据存储节点。DataNode存储的内容被称为块（block），DataNode允许客户端代码读取这些块数据。DataNode在本地磁盘上维护了一个非常重要表：
`块 --> 字节流`。DataNode在启动时会将表内容汇报给NameNode，在启动后也会周期性的向NameNode汇报表内容。

DataNode不断向NameNode提交请求，NameNode不能直接联系DataNode，NameNode仅仅返回DataNode调用的函数的返回值。

## DataNode启动过程

```
public class DataNode extends ReconfigurableBase
    implements InterDatanodeProtocol, ClientDatanodeProtocol,
        TraceAdminProtocol, DataNodeMXBean, ReconfigurationProtocol {
 
  //main
  public static void main(String args[]) {
    secureMain(args, null);
  }

  public static void secureMain(String args[], SecureResources resources) {
      ...
      DataNode datanode = createDataNode(args, null, resources);
      if (datanode != null) {
        datanode.join();
      } 
      ...
  }

  // 实例化 & 启动一个datanode daemon
  public static DataNode createDataNode(String args[], Configuration conf,
      SecureResources resources) throws IOException {
    DataNode dn = instantiateDataNode(args, conf, resources);
    if (dn != null) {
      dn.runDatanodeDaemon();
    }
    return dn;
  }

  // 实例化一个datanode对象及其secure resources
  public static DataNode instantiateDataNode(String args [], Configuration conf,
      SecureResources resources) throws IOException {
    ...
    Collection<StorageLocation> dataLocations = getStorageLocations(conf);
    UserGroupInformation.setConfiguration(conf);
    ...
    return makeInstance(dataLocations, conf, resources);
  }

  // 检查目录权限等
  static DataNode makeInstance(Collection<StorageLocation> dataDirs,
      Configuration conf, SecureResources resources) throws IOException {
   ...
   DataNodeDiskChecker dataNodeDiskChecker =
        new DataNodeDiskChecker(permission);
    List<StorageLocation> locations =
        checkStorageLocations(dataDirs, localFS, dataNodeDiskChecker);
    DefaultMetricsSystem.initialize("DataNode");
    ...
    return new DataNode(conf, locations, resources);
  }

  // 构造函数
  DataNode(final Configuration conf,
           final List<StorageLocation> dataDirs,
           final SecureResources resources) throws IOException {
    super(conf);
    ...
    try {
      startDataNode(conf, dataDirs, resources);
    } catch (IOException ie) {
      shutdown();
      throw ie;
    }
    ...
  }

  // 根据指定配置文件启动进程
  void startDataNode(Configuration conf, 
                     List<StorageLocation> dataDirs,
                     SecureResources resources
                     ) throws IOException {

    ...

    int volFailuresTolerated = dnConf.getVolFailuresTolerated();
    int volsConfigured = dnConf.getVolsConfigured();
    if (volFailuresTolerated < 0 || volFailuresTolerated >= volsConfigured) {
      throw new DiskErrorException("Invalid value configured for "
          + "dfs.datanode.failed.volumes.tolerated - " + volFailuresTolerated
          + ". Value configured is either less than 0 or >= "
          + "to the number of configured volumes (" + volsConfigured + ").");
    }

    storage = new DataStorage();
    
    // global DN settings
    registerMXBean();

    // 初始化DataXceiver
    initDataXceiver(conf);

    // 启动InfoServer
    startInfoServer(conf);
    pauseMonitor = new JvmPauseMonitor();
    pauseMonitor.init(conf);
    pauseMonitor.start();
  
    // BlockPoolTokenSecretManager is required to create ipc server.
    this.blockPoolTokenSecretManager = new BlockPoolTokenSecretManager();

    // 初始化IPC Server
    initIpcServer(conf);

    ecWorker = new ErasureCodingWorker(conf, this);
    blockRecoveryWorker = new BlockRecoveryWorker(this);

    blockPoolManager = new BlockPoolManager(this);
    blockPoolManager.refreshNamenodes(conf);

    readaheadPool = ReadaheadPool.getInstance();
    startMetricsLogger(conf);
  }

  void join() {
    while (shouldRun) {
      try {
        blockPoolManager.joinAll();
        if (blockPoolManager.getAllNamenodeThreads().size() == 0) {
          shouldRun = false;
        }
        // Terminate if shutdown is complete or 2 seconds after all BPs
        // are shutdown.
        synchronized(this) {
          wait(2000);
        }
      } catch (InterruptedException ex) {
        LOG.warn("Received exception in Datanode#join: " + ex);
      }
    }
  }
  
}
```

再看下DataNode deamon过程中提供的服务：
```
//目录结构：main/java/org/apache/hadoop/hdfs/server/datanode/DataNode.java
public class DataNode extends ReconfigurableBase
    implements InterDatanodeProtocol, ClientDatanodeProtocol,
        TraceAdminProtocol, DataNodeMXBean, ReconfigurationProtocol {
 
 ...

 public void runDatanodeDaemon() throws IOException {
    blockPoolManager.startAll();

    // start dataXceiveServer
    dataXceiverServer.start();
    if (localDataXceiverServer != null) {
      localDataXceiverServer.start();
    }
    ipcServer.setTracer(tracer);
    ipcServer.start();
    startPlugins(conf);
  }

  ...
}

//目录结构：main/java/org/apache/hadoop/hdfs/server/datanode/BlockPoolManager.java
// 管理datanode上的BPOfferService对象
class BlockPoolManager {

  ...

  synchronized void startAll() throws IOException {
    try {
      UserGroupInformation.getLoginUser().doAs(
          new PrivilegedExceptionAction<Object>() {
            @Override
            public Object run() throws Exception {
              for (BPOfferService bpos : offerServices) {
                bpos.start();
              }
              return null;
            }
          });
    }
    ... 
  }

  ...

}

//目录结构：main/java/org/apache/hadoop/hdfs/server/datanode/BPOfferService.java
// DN中每个实例都对应一个blockpool/namespace服务，用于处理该namespace到active和standby NNs 的心跳
class BPOfferService {
  
  ...

  void start() {
    for (BPServiceActor actor : bpServices) {
      actor.start();
    }
  }  

  ...

}

//目录结构：main/java/org/apache/hadoop/hdfs/server/datanode/BPServiceActor.java
class BPServiceActor implements Runnable {
  
  Thread bpThread; 
  ...

  //This must be called only by BPOfferService
  void start() {
    if ((bpThread != null) && (bpThread.isAlive())) {
      //Thread is started already
      return;
    }
    bpThread = new Thread(this, formatThreadName("heartbeating", nnAddr));
    bpThread.setDaemon(true); // needed for JUnit testing
    bpThread.start();

    if (lifelineSender != null) {
      lifelineSender.start();
    }
  }
  
  private final class LifelineSender implements Runnable, Closeable {
  
      ...

      public void start() {
      lifelineThread = new Thread(this, formatThreadName("lifeline",
          lifelineNnAddr));
      lifelineThread.setDaemon(true);
      lifelineThread.setUncaughtExceptionHandler(
          new Thread.UncaughtExceptionHandler() {
            @Override
            public void uncaughtException(Thread thread, Throwable t) {
              LOG.error(thread + " terminating on unexpected exception", t);
            }
          });
      lifelineThread.start();
    }
  ...
  }

}

```
`BPOfferService`启动两个线程: `heartbeating`和`lifeline`，lifeline是一个更轻量级的协议，见[HDFS-9239](https://issues.apache.org/jira/browse/HDFS-9239)。

从代码中可以看出，datanode启动时启动了heartbeat，ipc server, dataxeciver server。

协议如下：
>  /* ********************************************************************
>  Protocol when a client reads data from Datanode (Cur Ver: 9):
>  
>  Client's Request :
>  =================
>   
>     Processed in DataXceiver:
>     +----------------------------------------------+
>     | Common Header   | 1 byte OP == OP_READ_BLOCK |
>     +----------------------------------------------+
>     
>     Processed in readBlock() :
>     +-------------------------------------------------------------------------+
>     | 8 byte Block ID | 8 byte genstamp | 8 byte start offset | 8 byte length |
>     +-------------------------------------------------------------------------+
>     |   vInt length   |  <DFSClient id> |
>     +-----------------------------------+
>     
>     Client sends optional response only at the end of receiving data.
>       
>  DataNode Response :
>  ===================
>   
>    In readBlock() :
>    If there is an error while initializing BlockSender :
>       +---------------------------+
>       | 2 byte OP_STATUS_ERROR    | and connection will be closed.
>       +---------------------------+
>    Otherwise
>       +---------------------------+
>       | 2 byte OP_STATUS_SUCCESS  |
>       +---------------------------+
>       
>    Actual data, sent by BlockSender.sendBlock() :
>    
>      ChecksumHeader :
>      +--------------------------------------------------+
>      | 1 byte CHECKSUM_TYPE | 4 byte BYTES_PER_CHECKSUM |
>      +--------------------------------------------------+
>      Followed by actual data in the form of PACKETS: 
>      +------------------------------------+
>      | Sequence of data PACKETs ....      |
>      +------------------------------------+
>    
>    A "PACKET" is defined further below.
>    
>    The client reads data until it receives a packet with 
>    "LastPacketInBlock" set to true or with a zero length. It then replies
>    to DataNode with one of the status codes:
>    - CHECKSUM_OK:    All the chunk checksums have been verified
>    - SUCCESS:        Data received; checksums not verified
>    - ERROR_CHECKSUM: (Currently not used) Detected invalid checksums
>      +---------------+
>      | 2 byte Status |
>      +---------------+
>    
>    The DataNode expects all well behaved clients to send the 2 byte
>    status code. And if the the client doesn't, the DN will close the
>    connection. So the status code is optional in the sense that it
>    does not affect the correctness of the data. (And the client can
>    always reconnect.)
>    
>    PACKET : Contains a packet header, checksum and data. Amount of data
>    ======== carried is set by BUFFER_SIZE.
>    
>      +-----------------------------------------------------+
>      | 4 byte packet length (excluding packet header)      |
>      +-----------------------------------------------------+
>      | 8 byte offset in the block | 8 byte sequence number |
>      +-----------------------------------------------------+
>      | 1 byte isLastPacketInBlock                          |
>      +-----------------------------------------------------+
>      | 4 byte Length of actual data                        |
>      +-----------------------------------------------------+
>      | x byte checksum data. x is defined below            |
>      +-----------------------------------------------------+
>      | actual data ......                                  |
>      +-----------------------------------------------------+
>      
>      x = (length of data + BYTE_PER_CHECKSUM - 1)/BYTES_PER_CHECKSUM *
>          CHECKSUM_SIZE
>          
>      CHECKSUM_SIZE depends on CHECKSUM_TYPE (usually, 4 for CRC32)
>      
>      The above packet format is used while writing data to DFS also.
>      Not all the fields might be used while reading.
>    
>   ************************************************************************ */





