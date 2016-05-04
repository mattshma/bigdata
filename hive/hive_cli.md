# Hive client相关

- 显示数据库
若要长久设置的话，在hive-site.xml中添加如下行：
```
  <property>
    <name>hive.cli.print.current.db</name>
    <value>true</value>
  </property>
```
若临时设置下，只需要在hive CLI中设置`set hive.cli.print.current.db=true;`。

- 执行shell命令

在hive CLI中，只需在shell命令前加`!`即可执行。

- 执行dfs命令

在hive CLI中，若希望执行dfs命令，只需将hdfs省略即可，如`dfs -ls /`。


