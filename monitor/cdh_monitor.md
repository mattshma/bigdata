cdh相关api。


根据role重启实例：

```
# curl -X POST  -H "Content-Type:application/json" -u admin:admin  -d '{"items" : ["yarn-NODEMANAGER-a534b2ce0c27c39b2fc904ab550dd0d5"]}' 'http://xbd01-004:7180/api/v12/clusters/testCluster/services/yarn/roleCommands/restart'
```
返回结果如下：
```
{
  "errors" : [ ],
  "items" : [ {
    "id" : 620,
    "name" : "Restart",
    "startTime" : "2016-07-25T11:35:22.633Z",
    "active" : true,
    "serviceRef" : {
      "clusterName" : "cluster",
      "serviceName" : "yarn"
    },
    "roleRef" : {
      "clusterName" : "cluster",
      "serviceName" : "yarn",
      "roleName" : "yarn-NODEMANAGER-a534b2ce0c27c39b2fc904ab550dd0d5"
    }
  } ]
}
```
