# HBase Split 源码分析


在[doCompaction](https://github.com/apache/hbase/blob/branch-1.0/hbase-server/src/main/java/org/apache/hadoop/hbase/regionserver/CompactSplitThread.java#L475)中可以看到，当compaction做完后，会检查文件优先级，确定是否需要执行split操作。 


```` 
private void doCompaction(User user) { 
  ... 
  if (store.getCompactPriority() <= 0) { 
    requestSystemCompaction(region, store, "Recursive enqueue"); 
  } else { 
    // see if the compaction has caused us to exceed max region size 
    requestSplit(region); 
  } 
  ... 
} 
``` 

Store类的`getCompactPriority`方法再调用[getStoreCompactionPriority](https://github.com/apache/hbase/blob/branch-1.0/hbase-server/src/main/java/org/apache/hadoop/hbase/regionserver/DefaultStoreFileManager.java#L132)方法，`getStoreCompactionPriority`如下： 
``` 
public int getStoreCompactionPriority() { 
  int blockingFileCount = conf.getInt(HStore.BLOCKING_STOREFILES_KEY, HStore.DEFAULT_BLOCKING_STOREFILE_COUNT); 
  int priority = blockingFileCount - storefiles.size(); 
  return (priority == HStore.PRIORITY_USER) ? priority + 1 : priority; 
} 
``` 

对于[HStore](https://github.com/apache/hbase/blob/branch-1/hbase-server/src/main/java/org/apache/hadoop/hbase/regionserver/HStore.java#L118)，成员定义如下： 
``` 
public static final String BLOCKING_STOREFILES_KEY = "hbase.hstore.blockingStoreFiles"; 
public static final int DEFAULT_BLOCKING_STOREFILE_COUNT = 7; 
``` 

参考[hbase-default.xml](https://github.com/apache/hbase/blob/branch-1.0/hbase-common/src/main/resources/hbase-default.xml#L694)，`hbase.hstore.blockingStoreFiles`默认值为10，该参数作用是若任意Store中StoreFile达到这个数，则阻止该Region更新，直到compaction发生或超过`hbase.hstore.blockingWaitTime`设置的时间。 

`PRIORITY_USER`为用户指定的comapction请求的优先级，除非已经阻塞compaction操作，否则用户指定的compaction请求有最高优先级，该值[默认为1](https://github.com/apache/hbase/blob/branch-1.0/hbase-server/src/main/java/org/apache/hadoop/hbase/regionserver/Store.java#L57)。从这里也可以看出来，若priority等于用户指定compaction请求的priority，则其值需加1返回。 

回到`doCompaction()`，整个方法意思即：若返回值不大于0，说明Store中的StoreFile数仍达到blockingStoreFiles的值，此时触发系统级Compaction，反之则检查Region是否需要进行Split。 

若要执行Split，则执行`requestSplit()`方法，该方法先检查是否能执行Split，并获取split点，接着调用Split的`execute()`方法。[requestSplit](https://github.com/apache/hbase/blob/branch-1.0/hbase-server/src/main/java/org/apache/hadoop/hbase/regionserver/CompactSplitThread.java#L246)如下： 

``` 
public synchronized boolean requestSplit(final HRegion r) { 
  // don't split regions that are blocking 
  if (shouldSplitRegion() && r.getCompactPriority() >= Store.PRIORITY_USER) { 
    byte[] midKey = r.checkSplit(); 
    if (midKey != null) { 
      requestSplit(r, midKey); 
      return true; 
    } 
  } 
  return false; 
} 

public synchronized void requestSplit(final HRegion r, byte[] midKey) { 
  requestSplit(r, midKey, null); 
} 

public synchronized void requestSplit(final HRegion r, byte[] midKey, User user) { 
  ... 
  try { 
    this.splits.execute(new SplitRequest(r, midKey, this.server, user)); 
  } catch (RejectedExecutionException ree) { 
    LOG.info("Could not execute split for " + r, ree); 
  } 
} 
``` 

`shouldSplitRegion`检查RegionServer的online regioin是否达到`regionSplitLimit`，若未达到则返回True。`regionSplitLimit`默认值为1000，虽然hbase-1.0的[hbase-default.xml](https://github.com/apache/hbase/blob/branch-1.0/hbase-common/src/main/resources/hbase-default.xml)有两个值。 

``` 
public static final String REGION_SERVER_REGION_SPLIT_LIMIT = "hbase.regionserver.regionSplitLimit"; 
public static final int DEFAULT_REGION_SERVER_REGION_SPLIT_LIMIT= 1000; 
this.regionSplitLimit = conf.getInt(REGION_SERVER_REGION_SPLIT_LIMIT, DEFAULT_REGION_SERVER_REGION_SPLIT_LIMIT); 
``` 

Region类的[getCompactPriority](https://github.com/apache/hbase/blob/branch-1/hbase-server/src/main/java/org/apache/hadoop/hbase/regionserver/HRegion.java#L8133)和[checkSplit](https://github.com/apache/hbase/blob/branch-1/hbase-server/src/main/java/org/apache/hadoop/hbase/regionserver/HRegion.java#L8097)方法如下： 
``` 
/** 
* Return the splitpoint. null indicates the region isn't splittable 
* If the splitpoint isn't explicitly specified, it will go over the stores 
* to find the best splitpoint. Currently the criteria of best splitpoint 
* is based on the size of the store. 
*/ 
public byte[] checkSplit() { 
  // Can't split META 
  if (this.getRegionInfo().isMetaTable() || TableName.NAMESPACE_TABLE_NAME.equals(this.getRegionInfo().getTable())) { 
    return null; 
  } 

  // Can't split region which is in recovering state 
  if (this.isRecovering()) { 
    return null; 
  } 
  
  if (!splitPolicy.shouldSplit()) { 
    return null; 
  } 
  
  byte[] ret = splitPolicy.getSplitPoint(); 
  
  if (ret != null) { 
    try { 
      checkRow(ret, "calculated split"); 
    } catch (IOException e) { 
      LOG.error("Ignoring invalid split", e); 
      return null; 
    } 
  } 
  return ret; 
} 
  
/** 
* @return The priority that this region should have in the compaction queue 
*/ 
public int getCompactPriority() { 
  int count = Integer.MAX_VALUE; 
  for (Store store : stores.values()) { 
    count = Math.min(count, store.getCompactPriority()); 
  } 
  return count; 
} 
``` 

Store类的`getCompactPriority`方法在本文开头已介绍，此不赘述。 

`RegionSplitPolicy`类的[getSplitPoint](https://github.com/apache/hbase/blob/branch-1/hbase-server/src/main/java/org/apache/hadoop/hbase/regionserver/RegionSplitPolicy.java#L72)如下： 
``` 
protected byte[] getSplitPoint() { 
  byte[] explicitSplitPoint = this.region.getExplicitSplitPoint(); 
  // 若客户端指定split点则直接返回该指定split点。 
  if (explicitSplitPoint != null) { 
    return explicitSplitPoint; 
  } 
  List<Store> stores = region.getStores(); 
  
  byte[] splitPointFromLargestStore = null; 
  long largestStoreSize = 0; 
  for (Store s : stores) { 
    byte[] splitPoint = s.getSplitPoint(); 
    // Store also returns null if it has references as way of indicating it is not splittable 
    long storeSize = s.getSize(); 
    if (splitPoint != null && largestStoreSize < storeSize) { 
      splitPointFromLargestStore = splitPoint; 
    largestStoreSize = storeSize; 
  } 
} 
``` 

其调用HStore的[getSplitPoint](https://github.com/apache/hbase/blob/branch-1.0/hbase-server/src/main/java/org/apache/hadoop/hbase/regionserver/HStore.java#L1955)，如下： 

``` 
public byte[] getSplitPoint() { 
  this.lock.readLock().lock(); 
  try { 
    ... 
    // Not split-able if we find a reference store file present in the store. 
    if (hasReferences()) { 
      return null; 
    } 
    return this.storeEngine.getStoreFileManager().getSplitPoint(); 
    ... 
    } finally { 
      this.lock.readLock().unlock(); 
  } 
  return null; 
} 
``` 

对要Split的Store，先加读锁。对于有引用文件存在的Store，不会其进行Split。返回的split点的代码为`StoreUtils.getLargestFile(this.storefiles).getFileSplitPoint(this.kvComparator)`。 即先找到Store中的最大文件，然后调用其[getFileSplitPoint](https://github.com/apache/hbase/blob/branch-1.0/hbase-server/src/main/java/org/apache/hadoop/hbase/regionserver/StoreFile.java#L693)方法返回最大文件的最中间key作为split点： 
``` 
/** 
* Gets the approximate mid-point of this file that is optimal for use in splitting it. 
* @param comparator Comparator used to compare KVs. 
* @return The split point row, or null if splitting is not possible, or reader is null. 
*/ 
@SuppressWarnings("deprecation") 
byte[] getFileSplitPoint(KVComparator comparator) throws IOException { 
  if (this.reader == null) { 
    return null; 
  } 
  // Get first, last, and mid keys. Midkey is the key that starts block 
  // in middle of hfile. Has column and timestamp. Need to return just 
  // the row we want to split on as midkey. 
  byte [] midkey = this.reader.midkey(); 
  if (midkey != null) { 
    KeyValue mk = KeyValue.createKeyValueFromKey(midkey, 0, midkey.length); 
    byte [] fk = this.reader.getFirstKey(); 
    KeyValue firstKey = KeyValue.createKeyValueFromKey(fk, 0, fk.length); 
    byte [] lk = this.reader.getLastKey(); 
    KeyValue lastKey = KeyValue.createKeyValueFromKey(lk, 0, lk.length); 
    // if the midkey is the same as the first or last keys, we cannot (ever) split this region. 
    if (comparator.compareRows(mk, firstKey) == 0 || comparator.compareRows(mk, lastKey) == 0) { 
      if (LOG.isDebugEnabled()) { 
        LOG.debug("cannot split because midkey is the same as first or last row"); 
      } 
      return null; 
    } 
    return mk.getRow(); 
  } 
  return null; 
} 
``` 

再回到`requestSplit`方法中，拿到split点后，调用`SplitRequest`的[doSplitting](https://github.com/apache/hbase/blob/branch-1.0/hbase-server/src/main/java/org/apache/hadoop/hbase/regionserver/SplitRequest.java#L61)方法，该方法主要做了如下几件事： 

- 获得表的共享读锁，以防止表结构被修改。 
- 执行SplitTransaction对象的prepare方法，检查HRegion是否可被Split，并新建2个RegionInfo对象。若prepare成功的话，再执行SplitTransaction对象的execute方法。 
- 释放表锁。 

再说split事务（SplitTransaction）时，先看下整个Split事务有哪些[阶段](https://github.com/apache/hbase/blob/branch-1.0/hbase-server/src/main/java/org/apache/hadoop/hbase/regionserver/SplitTransaction.java#L111)： 

- STARTED 
- PREPARED 
- BEFORE_PRE_SPLIT_HOOK 
- AFTER_PRE_SPLIT_HOOK 
- SET_SPLITTING 
- CREATE_SPLIT_DIR 
- CLOSED_PARENT_REGION 
- OFFLINED_PARENT 
- STARTED_REGION_A_CREATION 
- STARTED_REGION_B_CREATION 
- OPENED_REGION_A 
- OPENED_REGION_B 
- PONR 
- BEFORE_POST_SPLIT_HOOK 
- AFTER_POST_SPLIT_HOOK 

Split事务中的[协同操作](https://github.com/apache/hbase/blob/branch-1.0/hbase-server/src/main/java/org/apache/hadoop/hbase/coordination/SplitTransactionCoordination.java#L30)阶段如下：

- [startSplitTransaction](https://github.com/apache/hbase/blob/branch-1.0/hbase-server/src/main/java/org/apache/hadoop/hbase/coordination/ZKSplitTransactionCoordination.java#L50)       
  所有split事务的准备/初始化工作须在此阶段完成。该函数主要作用是在zk中的region-in-transition目录下，根据执行split事务的region的rgion name创建临时目录，并将该目录设为 PENDING_SPLIT 状态。
- [waitForSplitTransaction](https://github.com/apache/hbase/blob/branch-1.0/hbase-server/src/main/java/org/apache/hadoop/hbase/coordination/ZKSplitTransactionCoordination.java#L135)     
  处理所有和split事务相关的协同工作，并直到这些工作完成为止。该函数主要作用等待master将正在split node的状态从 PENDING_SPLIT 更新为 SPLITTING，如果更新成功，则继续后续操作；否则循环等待直到更新成功或因node不存在或为空抛出异常。若node被删除或不处于PENDING_SPLIT 状态，则终止split。
- [completeSplitTransaction](https://github.com/apache/hbase/blob/branch-1.0/hbase-server/src/main/java/org/apache/hadoop/hbase/coordination/ZKSplitTransactionCoordination.java#L204)   
  所有为完成事务相关的操作。在PONR后调用。该函数作用是等待split事务执行结束后，将znode状态变为SPLIT。

下面分析split事务代码将按上述阶段进行。

SplitTransaction对象的[prepare](https://github.com/apache/hbase/blob/branch-1.0/hbase-server/src/main/java/org/apache/hadoop/hbase/regionserver/SplitTransaction.java#L221)方法如下： 
``` 
public boolean prepare() { 
  if (!this.parent.isSplittable()) return false; 
  if (this.splitrow == null) return false; 
  ...... 
  byte [] startKey = hri.getStartKey(); 
  byte [] endKey = hri.getEndKey(); 
  long rid = getDaughterRegionIdTimestamp(hri); 
  // 创建子regionInfo。
  this.hri_a = new HRegionInfo(hri.getTable(), startKey, this.splitrow, false, rid); 
  this.hri_b = new HRegionInfo(hri.getTable(), this.splitrow, endKey, false, rid); 
  // 标记split事务完成 PREPARED 阶段。
  this.journal.add(new JournalEntry(JournalEntryType.PREPARED)); 
  return true; 
} 

public PairOfSameType<HRegion> execute(final Server server, final RegionServerServices services, User user) throws IOException { 
  ...... 
  PairOfSameType<HRegion> regions = createDaughters(server, services, user); 
  ...... 
  return stepsAfterPONR(server, services, regions, user); 
} 

public PairOfSameType<HRegion> stepsAfterPONR(final Server server, final RegionServerServices services, final PairOfSameType<HRegion> regions, User user) throws IOException { 
  // 打开子region。
  openDaughters(server, services, regions.getFirst(), regions.getSecond()); 

  //调用completeSplitTransaction()，将zk中临时目录状态设为SPLIT。
  if (useCoordinatedStateManager(server)) {
    ((BaseCoordinatedStateManager) server.getCoordinatedStateManager())
        .getSplitTransactionCoordination().completeSplitTransaction(services, regions.getFirst(),
          regions.getSecond(), std, parent);
  }
  // split事务完成 BEFORE_POST_SPLIT_HOOK 阶段。
  journal.add(new JournalEntry(JournalEntryType.BEFORE_POST_SPLIT_HOOK)); 
  ...... 
  if (parent.getCoprocessorHost() != null) { 
    if (user == null) { 
      this.parent.getCoprocessorHost().postSplit(regions.getFirst(), regions.getSecond()); 
    } else { 
      parent.getCoprocessorHost().postSplit(regions.getFirst(), regions.getSecond()); 
  } 
  ...... 
  // split事务完成 AFTER_POST_SPLIT_HOOK 阶段。
  journal.add(new JournalEntry(JournalEntryType.AFTER_POST_SPLIT_HOOK)); 
  return regions; 
} 

PairOfSameType<HRegion> createDaughters(final Server server, final RegionServerServices services, User user) throws IOException { 
  ....... 
  // split事务完成 BEFORE_PRE_SPLIT_HOOK 阶段。
  journal.add(new JournalEntry(JournalEntryType.BEFORE_PRE_SPLIT_HOOK)); 

  // Coprocessor callback 
  if (this.parent.getCoprocessorHost() != null) { 
    if (user == null) { 
      // TODO: Remove one of these 
      parent.getCoprocessorHost().preSplit(); 
      parent.getCoprocessorHost().preSplit(splitrow); 
    } 
    ...... 
  } 
  
  // split事务完成 AFTER_PRE_SPLIT_HOOK 阶段。
  journal.add(new JournalEntry(JournalEntryType.AFTER_PRE_SPLIT_HOOK)); 

  ...... 

  PairOfSameType<HRegion> daughterRegions = stepsBeforePONR(server, services, testing); 
  
  final List<Mutation> metaEntries = new ArrayList<Mutation>(); 
  boolean ret = false; 
  if (this.parent.getCoprocessorHost() != null) { 
    if (user == null) { 
      ret = parent.getCoprocessorHost().preSplitBeforePONR(splitrow, metaEntries); 
    } 
    ...... 
    try { 
      for (Mutation p : metaEntries) { 
        HRegionInfo.parseRegionName(p.getRow()); 
      } 
    } 
   ...... 
  } 

  // the Point Of No Return。当达到PONR后，之后的操作若出现异常，需要停掉该regionserver。停rs的进程应修复未完成的split操作。offline的region将使用子region做为
  // 额外的列。如果子region在regionserver停掉时不删除，他们的引用文件会继续保存在父region目录下，修复.META.数据时，这些引用文件会指向这些region。
  // 
  // split事务完成 PONR 阶段。
  this.journal.add(new JournalEntry(JournalEntryType.PONR));

  // 修改.meta.中parent的状态。将parenet region状态更改为offline，增加splita和splitb记录（见HBASE-7721），该对.META.表的更新会让region判断如果发生失败的话，
  // 该region是否已split。若更新成功，则master继续，如果失败，则master回滚并重新上线parent region。 
  if (!testing && useZKForAssignment) { 
    if (metaEntries == null || metaEntries.isEmpty()) { 
      MetaTableAccessor.splitRegion(server.getConnection(), parent.getRegionInfo(), daughterRegions.getFirst().getRegionInfo(), daughterRegions.getSecond().getRegionInfo(), server.getServerName()); 
    } else { 
    offlineParentInMetaAndputMetaEntries(server.getConnection(), parent.getRegionInfo(), daughterRegions.getFirst().getRegionInfo(), daughterRegions .getSecond().getRegionInfo(), server.getServerName(), metaEntries); 
    } 
  } else if (services != null && !useZKForAssignment) { 
    if (!services.reportRegionStateTransition(TransitionCode.SPLIT_PONR, parent.getRegionInfo(), hri_a, hri_b)) { 
      // Passed PONR, let SSH clean it up 
      throw new IOException("Failed to notify master that split passed PONR: " + parent.getRegionInfo().getRegionNameAsString()); 
    } 
  } 
  return daughterRegions; 
} 

public PairOfSameType<HRegion> stepsBeforePONR(final Server server, final RegionServerServices services, boolean testing) throws IOException { 

  if (useCoordinatedStateManager(server)) { 
    ...... 
    // 为指定region在zk中创建一个PENDING_SPLIT状态的临时目录。 
    ((BaseCoordinatedStateManager) server.getCoordinatedStateManager()).getSplitTransactionCoordination().startSplitTransaction(parent, server.getServerName(), hri_a, hri_b); 
  } 
  ...... 
  // split事务完成 SET_SPLITTING 阶段。
  this.journal.add(new JournalEntry(JournalEntryType.SET_SPLITTING)); 
  if (useCoordinatedStateManager(server)) { 
    // 等待master将pending_split状态的目录转变为splitting。如果zk中该pending_split状态的目录不存在或不为pending_split转态，则终止split。 
    ((BaseCoordinatedStateManager) server.getCoordinatedStateManager()).getSplitTransactionCoordination().waitForSplitTransaction(services, parent, hri_a, hri_b, std); 
  } 
  
  // createSplitsDir()调用getSplitsDir()获取split目录.splits，并创建该目录。 
  this.parent.getRegionFileSystem().createSplitsDir(); 

  // split事务完成 CREATE_SPLIT_DIR 阶段。
  this.journal.add(new JournalEntry(JournalEntryType.CREATE_SPLIT_DIR)); 
  
  Map<byte[], List<StoreFile>> hstoreFilesToSplit = null; 
  Exception exceptionToThrow = null; 
  try{ 
    // 关闭该region，再关闭时，会等待该region上的flush memstore和compact操作结束。 
    hstoreFilesToSplit = this.parent.close(false); 
  } 

  // split事务完成 CLOSED_PARENT_REGION 阶段。
  if (exceptionToThrow != closedByOtherException) {
    this.journal.add(new JournalEntry(JournalEntryType.CLOSED_PARENT_REGION));
  }
  
  // 将该region从onlineregion中删除。 
  if (!testing) { 
    services.removeFromOnlineRegions(this.parent, null); 
  }
  // split事务完成OFFLINED_PARENT 阶段。 
  this.journal.add(new JournalEntry(JournalEntryType.OFFLINED_PARENT)); 
  
  // 创建引用文件。 
  Pair<Integer, Integer> expectedReferences = splitStoreFiles(hstoreFilesToSplit);
  // split事务进入STARTED_REGION_A_CREATION 阶段。 
  this.journal.add(new JournalEntry(JournalEntryType.STARTED_REGION_A_CREATION));
  HRegion a = this.parent.createDaughterRegionFromSplits(this.hri_a); 
  ...... 

  // split事务进入STARTED_REGION_B_CREATION 阶段。 
  this.journal.add(new JournalEntry(JournalEntryType.STARTED_REGION_B_CREATION));
  HRegion b = this.parent.createDaughterRegionFromSplits(this.hri_b); 
  
  return new PairOfSameType<HRegion>(a, b); 
} 

void openDaughters(final Server server, final RegionServerServices services, HRegion a, HRegion b) throws IOException {
  
    ...... 
    // 检查RegionServer是否挂掉，若没，则并行打开子region。
    DaughterOpener aOpener = new DaughterOpener(server, a);
    DaughterOpener bOpener = new DaughterOpener(server, b);
    aOpener.start();
    bOpener.start();
    try {
      aOpener.join();
      if (aOpener.getException() == null) {

        // split事务完成 OPENED_REGION_A 阶段。
        journal.add(new JournalEntry(JournalEntryType.OPENED_REGION_A));
      }
      bOpener.join();
      if (bOpener.getException() == null) {
        // split事务完成 OPENED_REGION_B 阶段。
        journal.add(new JournalEntry(JournalEntryType.OPENED_REGION_B));
      }
    ......

    if (services != null) {
        // add 2nd daughter first (see HBASE-4335)
        services.postOpenDeployTasks(b);
        // Should add it to OnlineRegions
        services.addToOnlineRegions(b);
        services.postOpenDeployTasks(a);
        services.addToOnlineRegions(a);
    }
  }
}
``` 

整个Split事务见下表：

 Phase  |  Function | Description 
---------|----------|--------------------
STARTED  | SplitTransaction() |  <ul><li>构造方法。</li></ul>
PREPARED | prepare() |  <ul><li>根据rowkey为两个子Region分别创建HRegionInfo对象。</li></ul>
BEFORE_PRE_SPLIT_HOOK | createDaughters() | <ul> <li>由execute()调用。</li> <li>确认RS正常。</li></ul>
AFTER_PRE_SPLIT_HOOK | createDaughters() |<ul><li>完成为preSplit加coprocessor hook。</li></ul>
SET_SPLITTING | stepsBeforePONR() | <ul><li>由createDaughters()调用</li><li>调用startSplitTransaction()，为指定region在zk中创建一个PENDING_SPLIT状态的临时目录。</li><li>调用waitForSplitTransaction()，等待master将zk中临时目录状态从PENDING_SPLIT更改为SPLITTING。</li></ul>
CREATE_SPLIT_DIR | stepsBeforePONR() |<ul><li>调用getSplitsDir()获取split目录.splits，并创建该目录。</li></ul>
CLOSED_PARENT_REGION | stepsBeforePONR() | <ul><li>flush该region的memstore后关闭该region。</li></ul>
OFFLINED_PARENT | stepsBeforePONR() |  <ul><li>在RegionServer的onlineregion中删除该region。</li></ul>
STARTED_REGION_A_CREATION | stepsBeforePONR() |<ul><li>创建引用文件</li><li>创建子region A。</li></ul>
STARTED_REGION_B_CREATION | stepsBeforePONR() | <ul><li>创建子region B。</li></ul>
PONR | createDaughters() |<ul><li>stepsBeforePONR()执行结束，回到createDaughters()。</li><li>Point Of No Return。该阶段之后的事务无法恢复，若出现错误，只能让RS挂掉，接着master ServerShutdownHandler 修复子region以防止数据丢失。在进入该阶段前会先调用preSplitBeforePONR()增加hook。</li></ul>
OPENED_REGION_A | openDaughters() |<ul><li>execute()调用stepsAfterPONR()，stepsAfterPONR()再调用openDaughters()</li><li>检查RS是否正常，若正常，则并行打开RegionA和RegionB</li></ul>
OPENED_REGION_B | openDaughters() |<ul><li>该阶段后，根据HBASE-4335，先更新zk中region B。</li><li>将region B加入onlineregion。</li><li>更新zk中region A，再将其加入onlineregion。</li></ul>
BEFORE_POST_SPLIT_HOOK | stepsAfterPONR() |<ul><li>调用完openDaughters()后，返回stepsAfterPONR()</li><li>调用completeSplitTransaction()，将zk中临时目录状态设为SPLIT。</li></ul>
AFTER_POST_SPLIT_HOOK | stepsAfterPONR() |<ul><li>调用postSplit()后，split事务进入该阶段。</li></ul>





