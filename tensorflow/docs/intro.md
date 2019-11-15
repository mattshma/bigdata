# Intro

## 概念
- 样本   
  一组记录的集合，其中每条记录是关于一个事件或对象的描述。
- 特征   
  样本的特点，如样本是几条鸢尾花数据，则特征为花萼长度、花瓣长度等。
- 标签   
  样本的分类，即尝试预测的内容。比如是山鸢尾还是变色鸢尾等。
- 模型  
  特征与标签的关系。对于鸢尾花问题，模型定义了花萼和花瓣测量值与鸢尾花品种之间的关系。
- 训练   
  训练是机器学习中的一个阶段，在此阶段中，模型会逐渐得到优化。

## 安装 TensorFlow
使用 Anaconda3 安装 TensorFlow，参考[这里](https://www.tensorflow.org/install/install_linux)。这里创建 Python3.6 的环境，如下：
```
// 创建名为 py3 的 python3.6.5 环境
$ conda create -n py3 python=3.6.5
// 安装 Jupyter、TensorFlow
$ conda install -n py3 jupyter tensorflow pandas
// 列举安装的包
$ conda list -n py3
// 激活
$ source activate py3
// 退出
$ source deactivate
```
这里使用 jupyter 做为学习 TensorFlow 的工具，进入 anaconda 环境后，运行 jupyter：   
- 生成配置文件：`$ jupyter notebook --generate-config`。
- 配置：  
修改配置如下：
```
c.NotebookApp.ip='*'
c.NotebookApp.open_browser = False
```
保存后退出。
- 设置 jupyter 密码：`jupyter notebook password`。
- 运行 jupyter: `jupyter notebook`。

## 运行 Demo


## 分析 Demo
### TensorFlow 编程堆栈
在分析 Demo 前，先看下 TensorFlow 的编程堆栈：

![TensorFlow 编程环境](../img/tensorflow_programming_environment.png)

### 过程分析

一般而言，运行 TensorFlow 主要是如下几个步骤：
- 导入和解析数据集。
- 创建特征列以描述数据。
- 选择模型类型。
- 训练模型。
- 评估模型的效果。
- 让经过训练的模型进行预测。




