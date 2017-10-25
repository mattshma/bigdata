# 创建 ssh 登录的 docker 镜像

由于需要使用 ssh 登录 docker 容器，或使用 sftp 上传下载文件，需要能以 ssh 登录容器，这里以 centos 为例，说下过程。

若想以 ssh 登录，需要以 centos 为基础新创建一个容器，主要参考 [SSH-Centos7-Dockerfile](https://github.com/CentOS/CentOS-Dockerfiles/tree/master/ssh/centos7)。

Dockerfile 如下：
```
FROM centos:centos7

RUN yum -y update; yum clean all
RUN yum -y install openssh-server passwd; yum clean all
ADD ./start.sh /start.sh
RUN mkdir /var/run/sshd

RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N '' 

RUN chmod 755 /start.sh
# EXPOSE 22
RUN ./start.sh
ENTRYPOINT ["/usr/sbin/sshd", "-D"]
```

start.sh 如下：
```
#!/bin/bash

__create_user() {
# Create a user to SSH into as.

USER=user
SSH_USERPASS=newpass
useradd $USER
echo -e "$SSH_USERPASS\n$SSH_USERPASS" | (passwd --stdin $USER)
echo $USER user password: $SSH_USERPASS
}

# Call all functions
__create_user
```
上述 user 和 newpass 为自定义变量。

然后按以下步骤操作：
- 打包：`# docker build --rm -t <username>/ssh:centos7 .`。
- 运行容器：`# docker run -d -p 22 <username>/ssh:centos7`。
- 获取容器端口信息：
```
# docker ps
CONTAINER ID        IMAGE                 COMMAND             CREATED             STATUS              PORTS                   NAMES
8c82a9287b23        <username>/ssh:centos7   /usr/sbin/sshd -D   4 seconds ago       Up 2 seconds        0.0.0.0:49154->22/tcp   mad_mccarthy        
```
- 通过 ssh 登录：`# ssh -p xxxx user@localhost`。
- 通过 sftp 登录：`sftp -oPort=xxxx user@localhost`。



