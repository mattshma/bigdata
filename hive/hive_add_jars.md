# Hive 添加 jar 的方法

在 Hive 中经常遇到需要添加辅助（或第三方）jar 包的情况。这里简单记录下几种方法。

- hive-cli 设置 --auxpath     
这种方法是最通用的方法。不过在使用过程中，jar 包最好使用绝对路径，否则可能会报`Wrong FS: file://...expected: file:///`的问题。虽然 [HIVE-7531](https://issues.apache.org/jira/browse/HIVE-7531) 已经解决了相对路径的问题的，但实际仍有可能报这个错误。
- ADD JAR 命令      
进入 hive 后，使用 ADD JAR 添加 jar 包，这种方法适用于添加自定义的 UDF jar。
- 设置 hive.aux.jars.path       
该参数可以 hive-site.xml 中进行设置，或进入 hive 后使用 SET 设置。设置值为 jars 的路径。
- 设置 HIVE_AUX_JARS_PATH      
在 hive-env.sh 中设置该变量。 

## 参考
- [How to add auxiliary Jars in Hive](http://chetnachaudhari.github.io/2016-02-16/how-to-add-auxiliary-jars-in-hive/)
- [HIVE-7531](https://issues.apache.org/jira/browse/HIVE-7531)
