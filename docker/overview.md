# Docker Overview

## 基本命令

### 进入正在运行的 docker
有如下几种方式可进入正在的 docker 容器中：
- docker exec
- docker attach
  这种方式一般不推荐使用，因为一般通过该命令进入的容器后，若退出该命令，则该容器也会退出。

### 设置代理

`sudo docker build --build-arg HTTPS_PROXY=http://proxy:port - < Dockerfile`


清除非正在运行的：
`docker system prune -a`
