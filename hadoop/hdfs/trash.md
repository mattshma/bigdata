Hadoop 的Trash功能
===

目前hadoop 集群经常会报磁盘空间不足的报警，在CM里设置的`fs.trash.interval` 为10天，因此Trash中的文件很大。在和相关业务部门讨论后，确定trash中的部分数据可以立即删除，因此需要写脚本每天去检查trash中的这些文件并删除之。其实在写业务部门删除文件时，对于不需要放trash中的文件，可指定`-skipTrash`删除即可。

先说下trash的原理。当trash设置时间后，在 Hdfs 中删除文件时，Namenode并不会立即将文件或目录删除掉，而是先放在Trash中。每个用户有自己相应的Trash，路径为`/user/username/.Trash`。根据`fs.trash.interval`中设置的日期，NameNode会在每次相隔日期时（格林威治时间为0点，因此北京时间为早上8点）启动后台线程Emptier检查每个用户的`.Trash`目录是否有过期文件（yyMMddHHmmss形式的），若有则删除，然后将当前要删除的目录（即Current目录）重命名为yyMMddHHmmss（注意hadoop1.x中目录名为yyMMddHHmm，因此从1.x升级到2.x后，trash中的文件不会被删除），因此在 `/user/username/.Trash`目录，可以看到目录的保留时间在0~2*`fs.trash.interval`之间（因为先删除再保存的缘故）。

trash目录和其它目录一样，只不过在从trash中删除时，不会将文件再放入trash，这时会真正的将文件删除。

对于我们的需要而言，需要写脚本去删除，因此使用`hdfs dfs -expunge` 或 `rm`去删除trash文件即可。
