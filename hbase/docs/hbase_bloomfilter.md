## BloomFilter


BloomFilter适用于Get操作，对于Scan没有效果。[passesBloomFilter](https://github.com/apache/hbase/blob/496fd9837a0fb199a516758a632fecfe59b0b480/hbase-server/src/main/java/org/apache/hadoop/hbase/regionserver/StoreFileReader.java#L247)如下：
```
  /**
   * Checks whether the given scan passes the Bloom filter (if present). Only
   * checks Bloom filters for single-row or single-row-column scans. Bloom
   * filter checking for multi-gets is implemented as part of the store
   * scanner system (see {@link StoreFileScanner#seekExactly}) and uses
   * the lower-level API {@link #passesGeneralRowBloomFilter(byte[], int, int)}
   * and {@link #passesGeneralRowColBloomFilter(Cell)}.
   *
   * @param scan the scan specification. Used to determine the row, and to
   *          check whether this is a single-row ("get") scan.
   * @param columns the set of columns. Only used for row-column Bloom
   *          filters.
   * @return true if the scan with the given column set passes the Bloom
   *         filter, or if the Bloom filter is not applicable for the scan.
   *         False if the Bloom filter is applicable and the scan fails it.
   */
  boolean passesBloomFilter(Scan scan, final SortedSet<byte[]> columns) {
    // Multi-column non-get scans will use Bloom filters through the
    // lower-level API function that this function calls.
    if (!scan.isGetScan()) {
      return true;
    }

    byte[] row = scan.getStartRow();
    switch (this.bloomFilterType) {
      case ROW:
        return passesGeneralRowBloomFilter(row, 0, row.length);

      case ROWCOL:
        if (columns != null && columns.size() == 1) {
	  ...
          return passesGeneralRowColBloomFilter(kvKey);
        }

        // For multi-column queries the Bloom filter is checked from the
        // seekExact operation.
        return true;

      default:
        return true;
    }
  }
```



### Reference
- [How are bloom filters used in HBase](https://www.quora.com/How-are-bloom-filters-used-in-HBase)
