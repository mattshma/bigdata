Heartbeating to namenode:7182 failed
----
在配置好yum源后，通过cm来添加新的机器，结果一直报错，如下：
```
Installation failed.Failed to receive heartbeat from agent.
Ensure that the host's hostname is configured properly.
Ensure that port 7182 is accesible on the Cloudera Manager server (check firewall rules).
Ensure that ports 9000 an 9001 are free on the host being added.
Check agent logs in /var/log/cloudera-scm-agent/ on the host being added (some of the logs can be found in the installation details)
```

查看待添加机器的cloudera-scm-agent.log，发现如下问题：
```
109938 MainThread agent        ERROR    Heartbeating to namenode:7182 failed.
Traceback (most recent call last):
  File "/usr/lib/cmf/agent/src/cmf/agent.py", line 766, in send_heartbeat
    response = self.requestor.request('heartbeat', dict(request=heartbeat))
  File "/usr/lib/cmf/agent/build/env/lib/python2.7/site-packages/avro-1.6.3-py2.7.egg/avro/ipc.py", line 139, in request
    return self.issue_request(call_request, message_name, request_datum)
  File "/usr/lib/cmf/agent/build/env/lib/python2.7/site-packages/avro-1.6.3-py2.7.egg/avro/ipc.py", line 249, in issue_request
    call_response = self.transceiver.transceive(call_request)
  File "/usr/lib/cmf/agent/build/env/lib/python2.7/site-packages/avro-1.6.3-py2.7.egg/avro/ipc.py", line 478, in transceive
    result = self.read_framed_message()
  File "/usr/lib/cmf/agent/build/env/lib/python2.7/site-packages/avro-1.6.3-py2.7.egg/avro/ipc.py", line 484, in read_framed_message
    framed_message = response_reader.read_framed_message()
  File "/usr/lib/cmf/agent/build/env/lib/python2.7/site-packages/avro-1.6.3-py2.7.egg/avro/ipc.py", line 412, in read_framed_message
    raise ConnectionClosedException("Reader read 0 bytes.")
ConnectionClosedException: Reader read 0 bytes.
```

namenode上启动的cloudera-scm-server，其版本为4.8.0。查看待加机器的cm版本，为5.0.2。将其卸载，去掉apt源中cloudera-scm5.0.2的源，重新安装即可。

当apt/yum源中同时有scm5和scm4的版本时，会优先安装高版本的软件。


