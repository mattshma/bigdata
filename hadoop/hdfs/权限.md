## 权限

### ACL
参考[linux文件权限说明](https://github.com/mattshma/docs/blob/master/linux/linux%E6%96%87%E4%BB%B6%E6%9D%83%E9%99%90%E8%AF%B4%E6%98%8E.md)，对linux权限位有个了解。在Hadoop中，

ls的权限位输出以+结束时，那么该文件或目录正在启用一个ACL。在配置文件中需要先开启acl：

```
<property>
<name>dfs.namenode.acls.enabled</name>
<value>true</value>
</property>
```

以用户ma（user：ma，group：ma）为例，在linux shell中相关命令如下：
```
# 添加acl
hdfs dfs -setfacl -R -m user:ma:r-x /user/hive/warehouse/test.db 
# 删除acl
hdfs dfs -setfacl -x user:ma /user/hive/warehouse/test.db
```

还可以定义 default acl 条目，新的子文件和子目录会自动继承 default acl 条目设置。只有目录才能设置 default acl 条目。如下：

```
hdfs dfs -setfacl -m default:group:ma:r-x /user/hive/warehouse/test.db
```


### Group Mapping
给定一个用户，通过group mapping服务，可得到该用户的属组，该服务由`hadoop.security.group.mapping`参数决定，默认情况下，该属性值为`org.apache.hadoop.security.JniBasedUnixGroupsMappingWithFallback`，即若JNI可用，通过JNI调用api来获取属组信息，若JNI不可用，该属性值为`org.apache.hadoop.security.ShellBasedUnixGroupsMapping`，即linux下的属组。当然，该属性值也可设置为`org.apache.hadoop.security.LdapGroupsMapping`来通过LDAP来获取属组信息。

对于HDFS而言，**用户与属组的对应关系需在NameNode上体现**，即若希望指定用户的属组，需要在NN上做调整。


### 案例
通过flume写的文件，其文件属性为`drwxrwx---  - flume hive /user/hive/warehouse/test.db`，此时若通过ma用户来访问数据，会报Permission Denied的问题，即使添加acl后，test.db上新建的目录ma用户仍然无法访问。根据上面说明，可给test.db目录加default acl，或者在nn上将ma的属组调整为hive。

参考
---
- [HDFS Permissions Guide](https://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-hdfs/HdfsPermissionsGuide.html)
- [HDFS ACLs: Fine-Grained Permissions for HDFS Files in Hadoop](http://zh.hortonworks.com/blog/hdfs-acls-fine-grained-permissions-hdfs-files-hadoop/)


