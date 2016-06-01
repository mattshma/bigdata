#Hadoop Metrics

以下讨论Hadoop相关的监控项。

## JVM
每个metric记录除包含以下监控项之一外，还包括如ProcessName，SessionID和Hostname之类的额外信息。
### MemNonHeap
- MemNonHeapUsedM
- MemNonHeapCommitedM
- MemNonHeapMaxM

### MemHeap
- MemHeapUsedM
- MemHeapCommitedM
- MemHeapMaxM

### Thread
- ThreadsNew
- ThreadsRunnable
- ThreadsBlocked
- ThreadsWaiting
- ThreadTimedWaiting
- ThreadTerminated

### GC
- GcCount
- GcTimeMillis

### Log
- LogFatal
- LogError
- LogWarn
- LogInfo


## RPC
每个metric记录除包含以下监控项之一外，还包括如Hostname，port等额外信息。

### ReceivedByte & SentBytes
- ReceivedBytes
- SentBytes

### Total number of RPC calls
- RpcQueueTimeNumOps/RpcProcessingTimeNumOps

### Average time
- RpcQueueTimeAvgTime
- RpcProcessingAvgTime

### Authentication
- RpcAuthorizationFailures
- RpcAuthenticationSuccesses

### Authorization
- RpcAuthorizationFailures
- RpcAuthorizationSuccesses

### Current number of open connections
- NumOpenConnections

### Current length of the call queue
- CallQueueLength   

### Show Total number of RPC calss
- rpcQueueTimenumsNumOps
- rpcProcessingTimenumsNumOps

### Show the nth percentile of RPC queue time in milliseconds
- rpcQueueTimenums90thPercentileLatency
- rpcProcessingTimenums90thPercentileLatency    

## RetryCache
- CacheHit
- CacheCleared
- CacheUpdated

## Rpcdetailed context
- methodnameNumOps
- methodnameAvgTime

## DFS content

### Namenode
- CreateFileOps
- SafeModeTime
- FsImageLoadTime

### FSNamesystem
- MissingBlocks
- ExpiredHeartbeats
- CapacityTotal(GB)
- CapacityUsed(GB)
- CapacityRemaining(GB)
- CapacityUsedNonDFS
- TotalLoad
- BlocksTotal
- FilesTotal
- PendingReplicationBlocks
- UnderReplicatedBlocks
- CorruptBlocks
- ScheduledReplicationBlocks
- PendingDeletionBlocks 
- PostponedMisreplicatedBlocks
- PendingDataNodeMessageCourt
- BlockCapacity

### JournalNode
- Syncs60sNumOps
- Syncs60s90thPercentileLatencyMicros
- Syncs300sNumOps
- Syncs300s90thPercentileLatencyMicros
- Syncs3600sNumOps
- Syncs3600s90thPercentileLatencyMicros

### DataNode
- BytesWritten
- BytesRead
- BlocksWritten
- BlocksRead
- BlocksReplicated
- BlocksRemoved
- BlocksVerified
- BlocksCached
- BlocksUncached
- ReadsFromLocalClient
- ReadsFromRemoteClient
- WritesFromLocalClient
- WritesFromRemoteClient
- ReadBlockOpNumOps
- WriteBlockOpNumOps
- ReadBlockOpAvgTime
- WriteBlockOpAvgTime
- IncrementalBlockReportsNumOps
- FlushNanosNumOps

## Yarn Context
### ClusterMetrics
- NumActiveNMs
- NumDecommissionedNMs
- NumLostNMs
- NumUnhealthyNMs
- NumRebootedNMs

### QueueMetrics
每个queue都有如下监控项:   
- running_0
- running_60
- running_300
- running_1440
- AppsSubmitted
- AppsRunning
- AppsPending   
- AppsCompleted
- AppsKilled
- AppsFailed
- AllocatedMB
- AllocatedVCores
- AllocatedContainers
- AvailableMB
- AvailableVCores
- PendingMB
- PendingVCores
- PendingContainers
- ReservedMB
- ReservedVCores
- ReservedContainers
- ActiveApplications

### NodeManagerMetrics
- containersLaunched
- containersCompleted
- containersFailed
- containersKilled
- containersIniting
- containersRunning
- allocatedContainers
- allocatedGB
- availableGB

## HBase
### Master
- hbase.master.numRegionServers
- hbase.master.numDeadRegionServers
- hbase.master.ritCount
- hbase.master.ritCountOverThreshold
- hbase.master.ritOldestAge

### RegionServer
- hbase.regionserver.regionCount
- hbase.regionserver.storeFileCount
- hbase.regionserver.storeFileSize
- hbase.regionserver.hlogFileCount
- hbase.regionserver.totalRequestCount
- hbase.regionserver.readRequestCount
- hbase.regionserver.writeRequestCount
- hbase.regionserver.numOpenConnections
- hbase.regionserver.numActiveHandler
- hbase.regionserver.numCallsInGeneralQueue
- hbase.regionserver.flushQueueLength
- hbase.regionserver.compactionQueueLength
- hbase.regionserver.blockCacheHitCount
- hbase.regionserver.blockCacheMissCount
- hbase.regionserver.blockCacheExpressHitPercent
- hbase.regionserver.percentFilesLocal
- hbase.regionserver.<op>_<measure>
- hbase.regionserver.GcTimeMillis
- hbase.regionserver.GcTimeMillisParNew
- hbase.regionserver.GcTimeMillisConcurrentMarkSweep
- hbase.regionserver.mutationsWithoutWALCount
- hbase.regionserver.authenticationSuccesses
- hbase.regionserver.authenticationFailures

## Hive
- DB是否挂掉
- MetaStore server是否挂掉

## Kafka
- 进程是否挂掉

## Flume
- 进程是否挂掉
- JVM监控

## 参考
- [Hadoop Monitor Metrics](https://hadoop.apache.org/docs/r2.7.2/hadoop-project-dist/hadoop-common/Metrics.html)
- [HBase Metrics](https://hbase.apache.org/book.html#hbase_metrics)
- [Monitoring Flume](https://cwiki.apache.org/confluence/display/FLUME/Monitoring+Flume)
- [Kafka Monitoring](http://kafka.apache.org/documentation.html#monitoring)
