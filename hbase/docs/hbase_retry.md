# HBase Retry

## BACKOFF

[HConstants.java](https://github.com/apache/hbase/blob/branch-1.2/hbase-common/src/main/java/org/apache/hadoop/hbase/HConstants.java#L575) 中 `public static final int [] RETRY_BACKOFF = {1, 2, 3, 5, 10, 20, 40, 100, 100, 100, 100, 200, 200};`

[ConnectionUtils.java](https://github.com/apache/hbase/blob/branch-1.2/hbase-client/src/main/java/org/apache/hadoop/hbase/client/ConnectionUtils.java#L52)中 getPauseTime 如下：
```
  public static long getPauseTime(final long pause, final int tries) {
    int ntries = tries;
    if (ntries >= HConstants.RETRY_BACKOFF.length) {
      ntries = HConstants.RETRY_BACKOFF.length - 1;
    }
    if (ntries < 0) {
      ntries = 0;
    }

    long normalPause = pause * HConstants.RETRY_BACKOFF[ntries];
    long jitter =  (long)(normalPause * RANDOM.nextFloat() * 0.01f); // 1% possible jitter
    return normalPause + jitter;
  }
```
