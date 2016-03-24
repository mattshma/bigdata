# Hive client相关

- 显示数据库

设置`Set hiveconf:hive.cli.print.current.db=true;`。

- 执行shell命令

在hive CLI中，只需在shell命令前加`!`即可执行。

- 执行dfs命令

在hive CLI中，若希望执行dfs命令，只需将hdfs省略即可，如`dfs -ls /`。


