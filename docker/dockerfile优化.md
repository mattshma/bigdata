# 优化 Dockerfile，减小镜像大小。

## 删除不必要文件
在 apt 下载软件后，可执行 `apt-get clean` 和 `rm -rf /var/lib/apt/lists/*` 删除包缓存中的所有 .deb 文件包；另外，apt-get install 过程中会加入很多可有可无的依赖，这部分不必要的内容可通过指定`--no-install-recommends` 不安装，如下：
```
RUN apt-get udpate && \
    apt-get install -y --no-install-recommends python-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
```

对于 pip 安装的包，可通过 `pip --no-cache-dir install` 指定不缓存文件。另外，对于从官网下载源，速度无疑太慢了，通常制作镜像时间大部分卡在这里，使用国内镜像源，能极大提升制作镜像的时间。这里推荐使用豆瓣的镜像。使用方法为：`pip install -i http://pypi.douban.com/simple/ --trusted-host=pypi.doubanio.com numpy`。

对于 ADD/COPY 拷贝的安装文件，在安装完成后，记得再将这些文件删除。

不过在测试 Dockerfile 中，先不要加上这些参数，以免因其他逻辑错误导致重复下载这些包，耗时太久。

- [Dockerfile Best Practices](http://crosbymichael.com/dockerfile-best-practices.html)
