# 安装numpy，scipy和sklearn

本来以为单纯pip就ok的，结果发现有一些依赖，所以这里主要记录下要安装的包，以免之后同样的需求还要上网查找。

## 升级Python
centos6.4默认安装的python版本是2.6的，这里先将其升级。过程如下。

- 安装开发工具包
命令为`yum groupinstall "Development tools"`。

- 安装部分包
命令：`yum install -y zlib-devel openssl-devel bzip2-devel ncurses-devel sqlite-devel gcc gcc-c++`。

- 安装python
下载[python](https://www.python.org/ftp/python/2.7.11/Python-2.7.11.tgz)，解压并安装。
```
# ./configure --prefix=/usr/local/python-2.7.11
# make;make install
# cd /usr/local
# ln -s python-2.7.11 python
```
编辑`/etc/bashrc`，添加`export PATH=/usr/local/python/bin:$PATH`，source该文件后查看python版本。

若`export PATH=$PATH:/usr/local/python/bin`，则python版本仍为2.6，还需要修改`/usr/bin/python`指向，并修改`/usr/bin/yum`中python指向。

## 安装setuptools和pip

这里是简单的安装，略过。

## 安装numpy，scipy，sklearn
如下：
```
# pip install numpy scipy sklearn
# python -c "import numpy; print numpy.__version__"
```

Done。

## python2.6安装问题

使用python2.6安装，有诸多依赖和问题，使用python2.7安装，问题都没了。对于python2.6，在安装sklearn时报错：
```
ImportError: Your installation of Scientific Python (SciPy) 0.7.2 is out-of-date.
    scikit-learn requires SciPy >= 0.9.
```
而在安装SciPy报错如下：
```
Running setup.py install for SciPy ... error
    Complete output from command /usr/bin/python -u -c "import setuptools, tokenize;__file__='/tmp/pip-build-Z9sinw/SciPy/setup.py';exec(compile(getattr(tokenize, 'open', open)(__file__).read().replace('\r\n', '\n'), __file__, 'exec'))" install --record /tmp/pip-5jtzmZ-record/install-record.txt --single-version-externally-managed --compile:
    lapack_opt_info:
    openblas_lapack_info:
      libraries openblas not found in ['/usr/local/lib64', '/usr/local/lib', '/usr/lib64', '/usr/lib']
      NOT AVAILABLE
```
可先将依赖安装好，或安装较高版本的scipy：`pip install --upgrade SciPy==0.10`，然后再安装sklearn。



