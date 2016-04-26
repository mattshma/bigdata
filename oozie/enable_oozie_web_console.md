#Enable Oozie Server Web Console


过程如下：
- 下载[ext-2.2.zip](http://dev.sencha.com/deploy/ext-2.2.zip)。
- 将ext-2.2.zip解压到`/var/lib/oozie`目录中，即`/var/lib/oozie/ext-2.2`。
- CDH的oozie的configuration中，勾选`Enable Oozie Server Web Console`。

**UPDATE: ext-2.2已在oozie中存在，路径:/var/lib/oozie/tomcat-deployment/webapps/oozie。即做个软链即可。**

然后刷新oozie web页面即可。


