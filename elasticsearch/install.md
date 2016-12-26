做如下修改：

/etc/sysctl.conf

```
vm.swappiness=1
fs.file-max=4294836225
vm.max_map_count=262144
```

/etc/security/limits.d/90-nproc.conf
```
es    -    noproc    unlimited
es    -    nofile    65536
es    -    memlock    unlimited
```

/opt/elasticsearch/config/elasticsearch.yaml:
```
cluster.name: elasticsearch_hbase_online
node.name: bd15-094.yzdns.com
path.data: /hadoop/es/data,/hadoop1/es/data,/hadoop2/es/data,/hadoop3/es/data,/hadoop4/es/data,/hadoop5/es/data,/hadoop6/es/data,/hadoop7/es/data,/hadoop8/es/data,/hadoop9/es/data,/hadoop10/es/data,/hadoop11/es/data
path.logs: /var/log/es
bootstrap.memory_lock: true
network.host: 10.6.28.26
http.port: 9200
discovery.zen.ping.unicast.hosts: ["10.6.28.24", "10.6.28.25", "10.6.28.26"]
discovery.zen.minimum_master_nodes: 2
gateway.recover_after_nodes: 3
gateway.expected_nodes: 3
gateway.recover_after_time: 3m
action.destructive_requires_name: true
```

```
# mkdir /hadoop{,1,2,3,4,5,6,7,8,9,10,11}/es
# chown -R es:es /hadoop{,1,2,3,4,5,6,7,8,9,10,11}/es
```





