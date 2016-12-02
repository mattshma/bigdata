# HBase Filter
在使用scan和get从HBase中读取数据时，可以通过filter来减少返回给客户端的数据量。

通过filter的[Class Hierarchy](https://hbase.apache.org/apidocs/org/apache/hadoop/hbase/filter/package-tree.html)，可以看到所有的比较器都继承自`FilterBase`。以下针对几个比较器进行说明。

## CompareFilter
[CompareFilter](https://hbase.apache.org/apidocs/org/apache/hadoop/hbase/filter/CompareFilter.html)提供了基于行，qualifier，value等的比较，其主要由比较符（operator）和比较器（comparator）两部分构成。

CompareFilter有如下几类：
- DependentColumnFilter
- FamilyFilter
- QualifierFilter
- RowFilter
- ValueFilter

其中[比较符](https://hbase.apache.org/apidocs/org/apache/hadoop/hbase/filter/CompareFilter.CompareOp.html)有如下类别：

- EQUAL   
  相等。
- GREATER       
  大于。
- GREATER_OR_EQUAL  
  大于等于。
- LESS   
  小于。
- LESS_OR_EQUAL    
  小于等于。
- NO_OP   
  无操作符。
- NOT_EQUAL   
  不相等。


而[比较器](https://hbase.apache.org/apidocs/org/apache/hadoop/hbase/filter/ByteArrayComparable.html)有如下几种：

- BinaryComparator    
  比较两个字节数组。
- BinaryPrefixComparator     
  匹配字节数组的指定前缀。
- BitComparator     
  指定的字节数组执行指定的位操作，判断返回结果是否为0。
- LongComparator    
  指定的long值与字节数组比较。
- NullComparator     
  是否为空。     
- RegexStringComparator        
  正则比较。   
- SubstringComparator     
  子字符串比较。    


以下举例说明：
```
hbase(main):013:0* import org.apache.hadoop.hbase.filter.RowFilter
=> Java::OrgApacheHadoopHbaseFilter::RowFilter
hbase(main):015:0* import org.apache.hadoop.hbase.filter.CompareFilter
=> Java::OrgApacheHadoopHbaseFilter::CompareFilter
hbase(main):017:0* import org.apache.hadoop.hbase.filter.SubstringComparator
=> Java::OrgApacheHadoopHbaseFilter::SubstringComparator
hbase(main):018:0> import org.apache.hadoop.hbase.filter.BinaryComparator
=> Java::OrgApacheHadoopHbaseFilter::BinaryComparator
hbase(main):034:0> scan 'game_role', {LIMIT => 5, FILTER => RowFilter.new(CompareFilter::CompareOp::EQUAL, SubstringComparator.new('0000e3y1darrvtmdevsnsrccihtt0c_51006001'))}
``` 
## 参考
- [org.apache.hadoop.hbase.filter](https://hbase.apache.org/apidocs/org/apache/hadoop/hbase/filter/package-summary.html)
- [HBase Filtering](https://www.cloudera.com/documentation/enterprise/latest/topics/admin_hbase_filtering.html)
